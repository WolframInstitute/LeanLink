/*
 * leanexport: read the NDJSON that lean4export writes (format 3.1.0) and write it as fixed-width binary tables, the
 * first step of checking an exported Lean development with TypeTheory through LeanLink's bridge, with no Lean code in
 * the way. It is plain C with no dependencies, and reads the file once, from standard input, so a compressed export is
 * piped in:
 *
 *     zstd -dc --long=31 solution.ndjson.zst | leanexport convert OUTDIR
 *
 * An export lists names ("in"), universe levels ("il") and expressions ("ie") by index, each after the ones it refers
 * to, then the declarations that use them. OUTDIR gets, all little-endian, with every index the export's own:
 *
 *   names.bin       16 bytes a name: u8 kind (0 anonymous, 1 string, 2 number), 3 bytes 0, u32 prefix, u64 string id
 *                   or number
 *   levels.bin      12 bytes a level: u32 kind, u32 a, u32 b, as the shim's fields table writes levels: 0 zero, 1 the
 *                   successor of level a, 2 max and 3 imax of a and b, 4 the parameter named a
 *   exprs.bin       20 bytes an expression: u32 kind, a, b, c, d, with the shim's kind codes: 0 bound variable (a the
 *                   index), 1 sort (a the level), 2 constant (a the name, b the level list), 3 application (a function,
 *                   b argument), 4 lambda and 5 forall (a binder name, b type, c body, d the binder: 0 default,
 *                   1 implicit, 2 strict implicit, 3 instance implicit), 6 let (a name, b type, c value, d body),
 *                   7 natural literal (a the string id of its decimal digits), 8 string literal (a its string id),
 *                   9 projection (a the structure's name, b the field index, c the term)
 *   depths.bin      u32 an expression: 0 for a leaf, else one more than its deepest part's, as the shim's table has it
 *   levellists.bin  the levels of each constant's level list, u32 each, and levellists.idx, 12 bytes a list: u64 offset
 *                   (in levels), u32 count
 *   strings.bin     the bytes of every string (name parts, literals, digits), and strings.idx, 12 bytes a string: u64
 *                   offset, u32 length
 *   decls.ndjson    the declaration lines as the export has them, in its order
 *   meta.json       the export's first line, which names the exporter, the format and the Lean that wrote it
 *   counts.txt      how many of each kind of line and node were read
 *
 * A line it cannot read, or an index out of order, stops it with the line number.
 *
 * From the tables, the dependency cone of some declarations, as Lean's kernel would need them, with no Lean either:
 *
 *     leanexport cone OUTDIR CONE.tsv root,root,... [target,target,...]
 *
 * A declaration depends on the constants of its type, of its value (a theorem's proof, a definition's body), and, for
 * an inductive block, of its types, constructors and recursors with their rules; a constructor or recursor stands for
 * its block, each quot constant for itself. CONE.tsv gets every constant of the cone, in the export's order: its name,
 * as Lean's Name.toString writes it, its kind (theorem, definition, opaque, axiom, quot, inductive, constructor,
 * recursor), and the root that first reached it. For each target it prints whether the cone holds it and, if so, one
 * path from a root down to it, each step a constant the one before names. Roots given as ?text list instead the
 * declared constants whose names contain text.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>

/* ---------- failure ---------- */

static unsigned long long g_line = 0;

static void fail(const char *what) {
    fprintf(stderr, "leanexport: line %llu: %s\n", g_line, what);
    exit(1);
}

/* ---------- a growing buffer ---------- */

typedef struct { char *data; size_t size, capacity; } Buffer;

static void buffer_reserve(Buffer *b, size_t more) {
    if (b->size + more <= b->capacity) return;
    size_t capacity = b->capacity ? b->capacity : 1 << 16;
    while (capacity < b->size + more) capacity *= 2;
    b->data = realloc(b->data, capacity);
    if (!b->data) fail("out of memory");
    b->capacity = capacity;
}

static void buffer_append(Buffer *b, const void *bytes, size_t n) {
    buffer_reserve(b, n);
    memcpy(b->data + b->size, bytes, n);
    b->size += n;
}

/* ---------- JSON, as much as the export uses ---------- */

enum { J_NULL, J_FALSE, J_TRUE, J_NUMBER, J_STRING, J_ARRAY, J_OBJECT };

typedef struct Json {
    int type;
    int64_t number;          /* J_NUMBER: integers only, as the export writes them */
    const char *string;      /* J_STRING: unescaped, in the line's string arena; and an object member's key */
    size_t length;
    const char *key;
    size_t key_length;
    struct Json *child;      /* J_ARRAY, J_OBJECT: the first element or member */
    struct Json *next;       /* the next element or member */
} Json;

static Json *g_nodes = NULL;
static size_t g_node_count = 0, g_node_capacity = 0;
static Buffer g_text = {0};   /* unescaped strings of the current line */

static Json *new_node(int type) {
    if (g_node_count == g_node_capacity) {
        /* nodes are referred to by pointer while the line is parsed, so the pool must not move: a line that needs
           more than the pool grows it before it starts, from its length (see parse_line) */
        fail("internal: node pool exhausted");
    }
    Json *n = &g_nodes[g_node_count++];
    memset(n, 0, sizeof *n);
    n->type = type;
    return n;
}

static const char *g_p;

static void skip_space(void) { while (*g_p == ' ' || *g_p == '\t' || *g_p == '\r' || *g_p == '\n') g_p++; }

static void put_utf8(uint32_t c) {
    char out[4];
    size_t n;
    if (c < 0x80) { out[0] = (char)c; n = 1; }
    else if (c < 0x800) { out[0] = (char)(0xC0 | (c >> 6)); out[1] = (char)(0x80 | (c & 0x3F)); n = 2; }
    else if (c < 0x10000) { out[0] = (char)(0xE0 | (c >> 12)); out[1] = (char)(0x80 | ((c >> 6) & 0x3F)); out[2] = (char)(0x80 | (c & 0x3F)); n = 3; }
    else { out[0] = (char)(0xF0 | (c >> 18)); out[1] = (char)(0x80 | ((c >> 12) & 0x3F)); out[2] = (char)(0x80 | ((c >> 6) & 0x3F)); out[3] = (char)(0x80 | (c & 0x3F)); n = 4; }
    buffer_append(&g_text, out, n);
}

static uint32_t hex4(void) {
    uint32_t v = 0;
    for (int i = 0; i < 4; i++) {
        char c = *g_p++;
        v <<= 4;
        if (c >= '0' && c <= '9') v |= (uint32_t)(c - '0');
        else if (c >= 'a' && c <= 'f') v |= (uint32_t)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') v |= (uint32_t)(c - 'A' + 10);
        else fail("bad \\u escape");
    }
    return v;
}

/* a string, unescaped into g_text; gives its offset there and its length */
static void parse_string(size_t *offset, size_t *length) {
    if (*g_p != '"') fail("expected a string");
    g_p++;
    *offset = g_text.size;
    for (;;) {
        const char *start = g_p;
        while (*g_p != '"' && *g_p != '\\' && *g_p != '\0') g_p++;
        buffer_append(&g_text, start, (size_t)(g_p - start));
        if (*g_p == '"') { g_p++; break; }
        if (*g_p == '\0') fail("unterminated string");
        g_p++;
        char e = *g_p++;
        switch (e) {
            case '"': buffer_append(&g_text, "\"", 1); break;
            case '\\': buffer_append(&g_text, "\\", 1); break;
            case '/': buffer_append(&g_text, "/", 1); break;
            case 'b': buffer_append(&g_text, "\b", 1); break;
            case 'f': buffer_append(&g_text, "\f", 1); break;
            case 'n': buffer_append(&g_text, "\n", 1); break;
            case 'r': buffer_append(&g_text, "\r", 1); break;
            case 't': buffer_append(&g_text, "\t", 1); break;
            case 'u': {
                uint32_t c = hex4();
                if (c >= 0xD800 && c <= 0xDBFF) {
                    if (g_p[0] != '\\' || g_p[1] != 'u') fail("lone high surrogate");
                    g_p += 2;
                    uint32_t low = hex4();
                    if (low < 0xDC00 || low > 0xDFFF) fail("bad low surrogate");
                    c = 0x10000 + ((c - 0xD800) << 10) + (low - 0xDC00);
                }
                put_utf8(c);
                break;
            }
            default: fail("bad escape");
        }
    }
    *length = g_text.size - *offset;
}

static Json *parse_value(void);

static Json *parse_value(void) {
    skip_space();
    char c = *g_p;
    if (c == '{' || c == '[') {
        Json *node = new_node(c == '{' ? J_OBJECT : J_ARRAY);
        char close = c == '{' ? '}' : ']';
        g_p++;
        skip_space();
        Json **tail = &node->child;
        if (*g_p == close) { g_p++; return node; }
        for (;;) {
            size_t key_offset = 0, key_length = 0;
            if (node->type == J_OBJECT) {
                skip_space();
                parse_string(&key_offset, &key_length);
                skip_space();
                if (*g_p != ':') fail("expected ':'");
                g_p++;
            }
            Json *value = parse_value();
            if (node->type == J_OBJECT) {
                /* offsets, made pointers once the line is read, since g_text may move while it grows */
                value->key = (const char *)(uintptr_t)key_offset;
                value->key_length = key_length;
            }
            *tail = value;
            tail = &value->next;
            skip_space();
            if (*g_p == ',') { g_p++; continue; }
            if (*g_p == close) { g_p++; break; }
            fail("expected ',' or the end of an object or array");
        }
        return node;
    }
    if (c == '"') {
        Json *node = new_node(J_STRING);
        size_t offset, length;
        parse_string(&offset, &length);
        node->string = (const char *)(uintptr_t)offset;
        node->length = length;
        return node;
    }
    if (c == '-' || (c >= '0' && c <= '9')) {
        Json *node = new_node(J_NUMBER);
        int negative = 0;
        if (*g_p == '-') { negative = 1; g_p++; }
        uint64_t v = 0;
        if (!(*g_p >= '0' && *g_p <= '9')) fail("bad number");
        while (*g_p >= '0' && *g_p <= '9') {
            uint64_t digit = (uint64_t)(*g_p - '0');
            if (v > (UINT64_MAX - digit) / 10) fail("number too large");
            v = v * 10 + digit;
            g_p++;
        }
        if (*g_p == '.' || *g_p == 'e' || *g_p == 'E') fail("a number that is not an integer");
        if (v > (uint64_t)INT64_MAX) fail("number too large");
        node->number = negative ? -(int64_t)v : (int64_t)v;
        return node;
    }
    if (strncmp(g_p, "true", 4) == 0) { g_p += 4; return new_node(J_TRUE); }
    if (strncmp(g_p, "false", 5) == 0) { g_p += 5; return new_node(J_FALSE); }
    if (strncmp(g_p, "null", 4) == 0) { g_p += 4; return new_node(J_NULL); }
    fail("unexpected character");
    return NULL;
}

/* turn the offsets parse_value kept into pointers into g_text, which no longer moves for this line */
static void fix_pointers(Json *n) {
    for (; n; n = n->next) {
        if (n->key_length || n->key) n->key = g_text.data + (uintptr_t)n->key;
        if (n->type == J_STRING) n->string = g_text.data + (uintptr_t)n->string;
        if (n->child) fix_pointers(n->child);
    }
}

static Json *parse_line(const char *line, size_t length) {
    /* a node needs at least one byte of the line, so the line's length bounds the nodes it can have */
    if (length + 16 > g_node_capacity) {
        g_node_capacity = length + 16;
        g_nodes = realloc(g_nodes, g_node_capacity * sizeof(Json));
        if (!g_nodes) fail("out of memory");
    }
    g_node_count = 0;
    g_text.size = 0;
    g_p = line;
    Json *root = parse_value();
    skip_space();
    if (*g_p != '\0') fail("text after the value");
    fix_pointers(root);
    return root;
}

static Json *member(const Json *object, const char *key) {
    size_t n = strlen(key);
    for (Json *m = object->child; m; m = m->next)
        if (m->key_length == n && memcmp(m->key, key, n) == 0) return m;
    return NULL;
}

static Json *require(const Json *object, const char *key) {
    Json *m = member(object, key);
    if (!m) { char message[128]; snprintf(message, sizeof message, "missing \"%s\"", key); fail(message); }
    return m;
}

static uint64_t require_index(const Json *object, const char *key) {
    Json *m = require(object, key);
    if (m->type != J_NUMBER || m->number < 0) { char message[128]; snprintf(message, sizeof message, "\"%s\" is not an index", key); fail(message); }
    return (uint64_t)m->number;
}

static uint32_t index32(uint64_t v) {
    if (v > UINT32_MAX) fail("an index past 2^32");
    return (uint32_t)v;
}

/* ---------- the tables ---------- */

static FILE *g_names, *g_levels, *g_exprs, *g_depths, *g_lists, *g_lists_idx, *g_strings, *g_strings_idx, *g_decls;
static uint64_t g_name_count = 1, g_level_count = 1, g_expr_count = 0, g_list_count = 0, g_list_offset = 0;
static uint64_t g_string_count = 0, g_string_offset = 0;
static uint32_t *g_depth = NULL;   /* every expression's depth, which an expression's parents read */
static size_t g_depth_capacity = 0;
static uint64_t g_counts[16];     /* expression kinds */
static uint64_t g_decl_counts[8]; /* thm, def, opaque, axiom, quot, inductive, other */

static FILE *open_out(const char *dir, const char *name) {
    char path[4096];
    snprintf(path, sizeof path, "%s/%s", dir, name);
    FILE *f = fopen(path, "wb");
    if (!f) { fprintf(stderr, "leanexport: cannot write %s: %s\n", path, strerror(errno)); exit(1); }
    setvbuf(f, NULL, _IOFBF, 1 << 22);
    return f;
}

static void write_u32(FILE *f, uint32_t v) { fwrite(&v, 4, 1, f); }

static void write_u64(FILE *f, uint64_t v) { fwrite(&v, 8, 1, f); }

static uint32_t add_string(const char *s, size_t n) {
    fwrite(s, 1, n, g_strings);
    write_u64(g_strings_idx, g_string_offset);
    write_u32(g_strings_idx, (uint32_t)n);
    g_string_offset += n;
    return index32(g_string_count++);
}

static void write_name(uint8_t kind, uint32_t prefix, uint64_t value) {
    uint8_t head[4] = {kind, 0, 0, 0};
    fwrite(head, 1, 4, g_names);
    write_u32(g_names, prefix);
    write_u64(g_names, value);
}

static void write_level(uint32_t kind, uint32_t a, uint32_t b) {
    write_u32(g_levels, kind); write_u32(g_levels, a); write_u32(g_levels, b);
}

static uint32_t depth_of(uint32_t expr) {
    if (expr >= g_expr_count) fail("an expression refers to one not yet read");
    return g_depth[expr];
}

static void write_expr(uint32_t kind, uint32_t a, uint32_t b, uint32_t c, uint32_t d, uint32_t depth) {
    write_u32(g_exprs, kind); write_u32(g_exprs, a); write_u32(g_exprs, b); write_u32(g_exprs, c); write_u32(g_exprs, d);
    write_u32(g_depths, depth);
    if (g_expr_count == g_depth_capacity) {
        g_depth_capacity = g_depth_capacity ? 2 * g_depth_capacity : 1 << 20;
        g_depth = realloc(g_depth, g_depth_capacity * sizeof(uint32_t));
        if (!g_depth) fail("out of memory");
    }
    g_depth[g_expr_count++] = depth;
    g_counts[kind]++;
}

static uint32_t max3(uint32_t a, uint32_t b, uint32_t c) { uint32_t m = a > b ? a : b; return m > c ? m : c; }

static uint32_t binder_code(const Json *info) {
    if (info->type != J_STRING) fail("binderInfo is not a string");
    if (info->length == 7 && memcmp(info->string, "default", 7) == 0) return 0;
    if (info->length == 8 && memcmp(info->string, "implicit", 8) == 0) return 1;
    if (info->length == 14 && memcmp(info->string, "strictImplicit", 14) == 0) return 2;
    if (info->length == 12 && memcmp(info->string, "instImplicit", 12) == 0) return 3;
    fail("unknown binderInfo");
    return 0;
}

static void expect_next(uint64_t index, uint64_t *count, const char *what) {
    if (index != *count) { char message[128]; snprintf(message, sizeof message, "%s %llu out of order (expected %llu)", what, (unsigned long long)index, (unsigned long long)*count); fail(message); }
}

static void read_name(const Json *line) {
    uint64_t index = require_index(line, "in");
    expect_next(index, &g_name_count, "name");
    Json *s = member(line, "str"), *n = member(line, "num");
    if (s) {
        Json *part = require(s, "str");
        if (part->type != J_STRING) fail("a name part that is not a string");
        write_name(1, index32(require_index(s, "pre")), add_string(part->string, part->length));
    } else if (n) {
        write_name(2, index32(require_index(n, "pre")), require_index(n, "i"));
    } else fail("a name neither \"str\" nor \"num\"");
    g_name_count++;
}

static void read_level(const Json *line) {
    uint64_t index = require_index(line, "il");
    expect_next(index, &g_level_count, "level");
    Json *m;
    if ((m = member(line, "succ"))) write_level(1, index32((uint64_t)m->number), 0);
    else if ((m = member(line, "max")) || (m = member(line, "imax"))) {
        uint32_t kind = member(line, "max") ? 2 : 3;
        if (m->type != J_ARRAY || !m->child || !m->child->next) fail("max/imax needs two levels");
        write_level(kind, index32((uint64_t)m->child->number), index32((uint64_t)m->child->next->number));
    } else if ((m = member(line, "param"))) write_level(4, index32((uint64_t)m->number), 0);
    else fail("an unknown level");
    g_level_count++;
}

static uint32_t read_level_list(const Json *us) {
    if (us->type != J_ARRAY) fail("\"us\" is not a list");
    uint32_t count = 0;
    for (Json *l = us->child; l; l = l->next) { write_u32(g_lists, index32((uint64_t)l->number)); count++; }
    write_u64(g_lists_idx, g_list_offset);
    write_u32(g_lists_idx, count);
    g_list_offset += count;
    return index32(g_list_count++);
}

static void read_expr(const Json *line) {
    uint64_t index = require_index(line, "ie");
    expect_next(index, &g_expr_count, "expression");
    Json *m;
    if ((m = member(line, "bvar"))) write_expr(0, index32((uint64_t)m->number), 0, 0, 0, 0);
    else if ((m = member(line, "sort"))) write_expr(1, index32((uint64_t)m->number), 0, 0, 0, 0);
    else if ((m = member(line, "const"))) write_expr(2, index32(require_index(m, "name")), read_level_list(require(m, "us")), 0, 0, 0);
    else if ((m = member(line, "app"))) {
        uint32_t f = index32(require_index(m, "fn")), a = index32(require_index(m, "arg"));
        uint32_t df = depth_of(f), da = depth_of(a);
        write_expr(3, f, a, 0, 0, (df > da ? df : da) + 1);
    } else if ((m = member(line, "lam")) || (m = member(line, "forallE"))) {
        uint32_t kind = member(line, "lam") ? 4 : 5;
        uint32_t t = index32(require_index(m, "type")), b = index32(require_index(m, "body"));
        uint32_t dt = depth_of(t), db = depth_of(b);
        write_expr(kind, index32(require_index(m, "name")), t, b, binder_code(require(m, "binderInfo")), (dt > db ? dt : db) + 1);
    } else if ((m = member(line, "letE"))) {
        uint32_t t = index32(require_index(m, "type")), v = index32(require_index(m, "value")), b = index32(require_index(m, "body"));
        write_expr(6, index32(require_index(m, "name")), t, v, b, max3(depth_of(t), depth_of(v), depth_of(b)) + 1);
    } else if ((m = member(line, "natVal"))) {
        if (m->type != J_STRING) fail("natVal is not a string of digits");
        write_expr(7, add_string(m->string, m->length), 0, 0, 0, 0);
    } else if ((m = member(line, "strVal"))) {
        if (m->type != J_STRING) fail("strVal is not a string");
        write_expr(8, add_string(m->string, m->length), 0, 0, 0, 0);
    } else if ((m = member(line, "proj"))) {
        uint32_t t = index32(require_index(m, "struct"));
        write_expr(9, index32(require_index(m, "typeName")), index32(require_index(m, "idx")), t, 0, depth_of(t) + 1);
    } else fail("an unknown expression");
}

static int is_decl(const Json *line) {
    static const char *kinds[] = {"thm", "def", "opaque", "axiom", "quot", "inductive"};
    for (int i = 0; i < 6; i++) if (member(line, kinds[i])) { g_decl_counts[i]++; return 1; }
    return 0;
}

static void make_dir(const char *dir) {
    if (mkdir(dir, 0755) != 0 && errno != EEXIST) { fprintf(stderr, "leanexport: cannot make %s: %s\n", dir, strerror(errno)); exit(1); }
}

static int convert(const char *dir) {
    make_dir(dir);
    g_names = open_out(dir, "names.bin");
    g_levels = open_out(dir, "levels.bin");
    g_exprs = open_out(dir, "exprs.bin");
    g_depths = open_out(dir, "depths.bin");
    g_lists = open_out(dir, "levellists.bin");
    g_lists_idx = open_out(dir, "levellists.idx");
    g_strings = open_out(dir, "strings.bin");
    g_strings_idx = open_out(dir, "strings.idx");
    g_decls = open_out(dir, "decls.ndjson");
    FILE *meta = open_out(dir, "meta.json");
    /* index 0 is the anonymous name and the level zero, which the export does not list */
    write_name(0, 0, 0);
    write_level(0, 0, 0);

    char *line = NULL;
    size_t capacity = 0;
    ssize_t length;
    uint64_t names_read = 0, levels_read = 0, exprs_read = 0, decls_read = 0;
    while ((length = getline(&line, &capacity, stdin)) > 0) {
        g_line++;
        while (length > 0 && (line[length - 1] == '\n' || line[length - 1] == '\r')) line[--length] = '\0';
        if (length == 0) continue;
        Json *root = parse_line(line, (size_t)length);
        if (root->type != J_OBJECT) fail("a line that is not an object");
        if (member(root, "ie")) { read_expr(root); exprs_read++; }
        else if (member(root, "in")) { read_name(root); names_read++; }
        else if (member(root, "il")) { read_level(root); levels_read++; }
        else if (is_decl(root)) { fwrite(line, 1, (size_t)length, g_decls); fputc('\n', g_decls); decls_read++; }
        else if (member(root, "meta")) { fwrite(line, 1, (size_t)length, meta); fputc('\n', meta); }
        else fail("a line of an unknown kind");
    }
    free(line);
    FILE *files[] = {g_names, g_levels, g_exprs, g_depths, g_lists, g_lists_idx, g_strings, g_strings_idx, g_decls, meta};
    for (size_t i = 0; i < sizeof files / sizeof files[0]; i++) if (fclose(files[i]) != 0) fail("a write failed");

    FILE *counts = open_out(dir, "counts.txt");
    static const char *expr_kinds[] = {"bvar", "sort", "const", "app", "lam", "forallE", "letE", "natVal", "strVal", "proj"};
    static const char *decl_kinds[] = {"thm", "def", "opaque", "axiom", "quot", "inductive"};
    fprintf(counts, "lines %llu\nnames %llu\nlevels %llu\nexprs %llu\ndecls %llu\n", g_line, (unsigned long long)names_read,
        (unsigned long long)levels_read, (unsigned long long)exprs_read, (unsigned long long)decls_read);
    for (int i = 0; i < 10; i++) fprintf(counts, "expr %s %llu\n", expr_kinds[i], (unsigned long long)g_counts[i]);
    for (int i = 0; i < 6; i++) fprintf(counts, "decl %s %llu\n", decl_kinds[i], (unsigned long long)g_decl_counts[i]);
    uint32_t deepest = 0;
    for (uint64_t i = 0; i < g_expr_count; i++) if (g_depth[i] > deepest) deepest = g_depth[i];
    fprintf(counts, "deepest %u\n", deepest);
    fclose(counts);
    fprintf(stderr, "leanexport: %llu lines: %llu names, %llu levels, %llu expressions, %llu declarations; deepest %u\n", g_line,
        (unsigned long long)names_read, (unsigned long long)levels_read, (unsigned long long)exprs_read, (unsigned long long)decls_read, deepest);
    return 0;
}

/* ---------- the tables, read back ---------- */

typedef struct { const uint8_t *data; size_t size; } Mapped;

static Mapped map_file(const char *dir, const char *name) {
    char path[4096];
    snprintf(path, sizeof path, "%s/%s", dir, name);
    int fd = open(path, O_RDONLY);
    if (fd < 0) { fprintf(stderr, "leanexport: cannot read %s: %s\n", path, strerror(errno)); exit(1); }
    struct stat st;
    if (fstat(fd, &st) != 0) { fprintf(stderr, "leanexport: cannot stat %s\n", path); exit(1); }
    Mapped m = {NULL, (size_t)st.st_size};
    if (m.size > 0) {
        void *p = mmap(NULL, m.size, PROT_READ, MAP_PRIVATE, fd, 0);
        if (p == MAP_FAILED) { fprintf(stderr, "leanexport: cannot map %s\n", path); exit(1); }
        m.data = p;
    }
    close(fd);
    return m;
}

static Mapped t_names, t_exprs, t_strings, t_strings_idx;

static uint8_t name_kind(uint32_t id) { return t_names.data[(size_t)id * 16]; }

static uint32_t name_prefix(uint32_t id) { uint32_t v; memcpy(&v, t_names.data + (size_t)id * 16 + 4, 4); return v; }

static uint64_t name_value(uint32_t id) { uint64_t v; memcpy(&v, t_names.data + (size_t)id * 16 + 8, 8); return v; }

static const char *string_at(uint64_t id, uint32_t *length) {
    uint64_t offset; uint32_t n;
    memcpy(&offset, t_strings_idx.data + id * 12, 8);
    memcpy(&n, t_strings_idx.data + id * 12 + 8, 4);
    *length = n;
    return (const char *)t_strings.data + offset;
}

static void expr_row(uint32_t id, uint32_t row[5]) { memcpy(row, t_exprs.data + (size_t)id * 20, 20); }

/* ---------- names as Lean's Name.toString writes them ---------- */

/* the code point at s, and how many bytes it takes */
static uint32_t utf8_at(const unsigned char *s, size_t n, size_t *width) {
    unsigned char c = s[0];
    if (c < 0x80 || n < 2) { *width = 1; return c; }
    if ((c & 0xE0) == 0xC0) { *width = 2; return ((uint32_t)(c & 0x1F) << 6) | (s[1] & 0x3F); }
    if ((c & 0xF0) == 0xE0 && n >= 3) { *width = 3; return ((uint32_t)(c & 0x0F) << 12) | ((uint32_t)(s[1] & 0x3F) << 6) | (s[2] & 0x3F); }
    if (n >= 4) { *width = 4; return ((uint32_t)(c & 0x07) << 18) | ((uint32_t)(s[1] & 0x3F) << 12) | ((uint32_t)(s[2] & 0x3F) << 6) | (s[3] & 0x3F); }
    *width = 1;
    return c;
}

/* Lean's isLetterLike, isSubScriptAlnum, isIdFirst and isIdRest (Init/Meta/Defs.lean); Char.isAlpha is ASCII only */
static int letter_like(uint32_t c) {
    return (0x3b1 <= c && c <= 0x3c9 && c != 0x3bb) || (0x391 <= c && c <= 0x3A9 && c != 0x3A0 && c != 0x3A3) ||
        (0x3ca <= c && c <= 0x3fb) || (0x1f00 <= c && c <= 0x1ffe) || (0x2100 <= c && c <= 0x214f) ||
        (0x1d49c <= c && c <= 0x1d59f) || (0x00c0 <= c && c <= 0x00ff && c != 0x00d7 && c != 0x00f7) || (0x0100 <= c && c <= 0x017f);
}

static int subscript_alnum(uint32_t c) {
    return (0x2080 <= c && c <= 0x2089) || (0x2090 <= c && c <= 0x209c) || (0x1d62 <= c && c <= 0x1d6a) || c == 0x2c7c;
}

static int ascii_alpha(uint32_t c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }

static int id_first(uint32_t c) { return ascii_alpha(c) || c == '_' || letter_like(c); }

static int id_rest(uint32_t c) {
    return ascii_alpha(c) || (c >= '0' && c <= '9') || c == '_' || c == '\'' || c == '!' || c == '?' || letter_like(c) || subscript_alnum(c);
}

static int needs_no_escape(const char *s, uint32_t n) {
    size_t i = 0, width;
    uint32_t c = utf8_at((const unsigned char *)s, n, &width);
    if (!id_first(c)) return 0;
    for (i = width; i < n; i += width) if (!id_rest(utf8_at((const unsigned char *)s + i, n - i, &width))) return 0;
    return 1;
}

static int contains(const char *s, uint32_t n, const char *part) {
    size_t k = strlen(part);
    for (size_t i = 0; i + k <= n; i++) if (memcmp(s + i, part, k) == 0) return 1;
    return 0;
}

/* the last string component, past numeric ones, as hasMacroScopes and isInaccessibleUserName look at it */
static int last_string(uint32_t id, const char **s, uint32_t *n) {
    while (id && name_kind(id) == 2) id = name_prefix(id);
    if (!id || name_kind(id) != 1) return 0;
    *s = string_at(name_value(id), n);
    return 1;
}

static void append_component(Buffer *out, uint32_t id, int escape) {
    uint8_t kind = name_kind(id);
    uint32_t prefix = name_prefix(id);
    if (prefix) { append_component(out, prefix, escape); buffer_append(out, ".", 1); }
    if (kind == 2) {
        char digits[32];
        int n = snprintf(digits, sizeof digits, "%llu", (unsigned long long)name_value(id));
        buffer_append(out, digits, (size_t)n);
        return;
    }
    uint32_t n;
    const char *s = string_at(name_value(id), &n);
    /* escapePart: a valid identifier as it is; else «s», unless s holds », when it stays as it is */
    if (escape && (n == 0 || (!needs_no_escape(s, n) && !contains(s, n, "\xC2\xBB")))) {
        buffer_append(out, "\xC2\xAB", 2);
        buffer_append(out, s, n);
        buffer_append(out, "\xC2\xBB", 2);
    } else buffer_append(out, s, n);
}

/* Name.toString with escape := true: escaping is off for a name with macro scopes, an inaccessible one, and
   delaborator pseudo-syntax (`_`, or a root starting with # or ?) */
static char *name_string(uint32_t id) {
    Buffer out = {0};
    if (id == 0) { buffer_append(&out, "[anonymous]", 12); return out.data; }
    int escape = 1;
    const char *s; uint32_t n;
    if (last_string(id, &s, &n)) {
        if (n == 4 && memcmp(s, "_hyg", 4) == 0) escape = 0;
        if (contains(s, n, "\xE2\x9C\x9D") || (n == 13 && memcmp(s, "_inaccessible", 13) == 0)) escape = 0;
    }
    uint32_t root = id;
    while (name_prefix(root)) root = name_prefix(root);
    if (name_kind(root) == 1) {
        const char *r = string_at(name_value(root), &n);
        if (n > 0 && (r[0] == '#' || r[0] == '?')) escape = 0;
        if (id == root && n == 1 && r[0] == '_') escape = 0;
    }
    append_component(&out, id, escape);
    buffer_append(&out, "", 1);
    return out.data;
}

/* ---------- declarations ---------- */

enum { K_THEOREM, K_DEFINITION, K_OPAQUE, K_AXIOM, K_QUOT, K_INDUCTIVE, K_CONSTRUCTOR, K_RECURSOR };

static const char *kind_names[] = {"theorem", "definition", "opaque", "axiom", "quot", "inductive", "constructor", "recursor"};

typedef struct { uint32_t name; uint8_t kind; uint32_t decl; } Member;

typedef struct {
    uint32_t first_member, member_count;   /* its constants, in members */
    uint32_t first_root, root_count;       /* the expressions it depends through, in expr_roots */
} Decl;

static Member *g_members; static size_t g_member_count, g_member_capacity;
static uint32_t *g_expr_roots; static size_t g_expr_root_count, g_expr_root_capacity;
static Decl *g_decl_list; static size_t g_decl_count, g_decl_capacity;

static void push_member(uint32_t name, uint8_t kind) {
    if (g_member_count == g_member_capacity) { g_member_capacity = g_member_capacity ? 2 * g_member_capacity : 1 << 16; g_members = realloc(g_members, g_member_capacity * sizeof(Member)); }
    g_members[g_member_count++] = (Member){name, kind, (uint32_t)g_decl_count};
}

static void push_root(uint64_t expr) {
    if (g_expr_root_count == g_expr_root_capacity) { g_expr_root_capacity = g_expr_root_capacity ? 2 * g_expr_root_capacity : 1 << 16; g_expr_roots = realloc(g_expr_roots, g_expr_root_capacity * sizeof(uint32_t)); }
    g_expr_roots[g_expr_root_count++] = index32(expr);
}

static void add_constant(const Json *c, uint8_t kind) {
    push_member(index32(require_index(c, "name")), kind);
    push_root(require_index(c, "type"));
    Json *value = member(c, "value");
    if (value) push_root((uint64_t)value->number);
}

static void read_decl(const Json *line) {
    if (g_decl_count == g_decl_capacity) { g_decl_capacity = g_decl_capacity ? 2 * g_decl_capacity : 1 << 16; g_decl_list = realloc(g_decl_list, g_decl_capacity * sizeof(Decl)); }
    Decl d = {(uint32_t)g_member_count, 0, (uint32_t)g_expr_root_count, 0};
    static const char *simple[] = {"thm", "def", "opaque", "axiom", "quot"};
    static const uint8_t simple_kinds[] = {K_THEOREM, K_DEFINITION, K_OPAQUE, K_AXIOM, K_QUOT};
    Json *m = NULL;
    for (int i = 0; i < 5; i++) if ((m = member(line, simple[i]))) { add_constant(m, simple_kinds[i]); break; }
    if (!m) {
        Json *block = require(line, "inductive");
        for (Json *t = require(block, "types")->child; t; t = t->next) add_constant(t, K_INDUCTIVE);
        for (Json *c = require(block, "ctors")->child; c; c = c->next) add_constant(c, K_CONSTRUCTOR);
        for (Json *r = require(block, "recs")->child; r; r = r->next) {
            add_constant(r, K_RECURSOR);
            for (Json *rule = require(r, "rules")->child; rule; rule = rule->next) push_root(require_index(rule, "rhs"));
        }
    }
    d.member_count = (uint32_t)g_member_count - d.first_member;
    d.root_count = (uint32_t)g_expr_root_count - d.first_root;
    g_decl_list[g_decl_count++] = d;
}

/* ---------- a map from names to members ---------- */

static int64_t *g_by_name;     /* name id -> member index, or -1 */
static size_t g_name_total;

static int64_t member_of_name(uint32_t name) { return name < g_name_total ? g_by_name[name] : -1; }

/* a constant's name, as text, to its member: every member's name string, kept sorted */
typedef struct { char *text; uint32_t member; } NamedMember;

static NamedMember *g_named; static size_t g_named_count;

static int compare_named(const void *a, const void *b) { return strcmp(((const NamedMember *)a)->text, ((const NamedMember *)b)->text); }

static int64_t member_by_text(const char *text) {
    size_t lo = 0, hi = g_named_count;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        int c = strcmp(g_named[mid].text, text);
        if (c == 0) return g_named[mid].member;
        if (c < 0) lo = mid + 1; else hi = mid;
    }
    return -1;
}

/* ---------- the cone ---------- */

static int cone(const char *dir, const char *out_path, const char *roots_text, const char *targets_text) {
    t_names = map_file(dir, "names.bin");
    t_exprs = map_file(dir, "exprs.bin");
    t_strings = map_file(dir, "strings.bin");
    t_strings_idx = map_file(dir, "strings.idx");
    g_name_total = t_names.size / 16;
    size_t expr_total = t_exprs.size / 20;

    /* the declarations */
    char path[4096];
    snprintf(path, sizeof path, "%s/decls.ndjson", dir);
    FILE *decls = fopen(path, "rb");
    if (!decls) { fprintf(stderr, "leanexport: cannot read %s\n", path); return 1; }
    char *line = NULL; size_t capacity = 0; ssize_t length;
    g_line = 0;
    while ((length = getline(&line, &capacity, decls)) > 0) {
        g_line++;
        while (length > 0 && (line[length - 1] == '\n' || line[length - 1] == '\r')) line[--length] = '\0';
        read_decl(parse_line(line, (size_t)length));
    }
    fclose(decls);
    free(line);
    g_by_name = malloc(g_name_total * sizeof(int64_t));
    for (size_t i = 0; i < g_name_total; i++) g_by_name[i] = -1;
    g_named = malloc(g_member_count * sizeof(NamedMember));
    for (size_t i = 0; i < g_member_count; i++) {
        g_by_name[g_members[i].name] = (int64_t)i;
        g_named[i] = (NamedMember){name_string(g_members[i].name), (uint32_t)i};
    }
    g_named_count = g_member_count;
    qsort(g_named, g_named_count, sizeof(NamedMember), compare_named);

    /* roots of the form ?text list the declared constants whose names contain text, to find a root's exact name */
    if (roots_text[0] == '?') {
        for (size_t i = 0; i < g_named_count; i++)
            if (strstr(g_named[i].text, roots_text + 1)) printf("%s\t%s\n", g_named[i].text, kind_names[g_members[g_named[i].member].kind]);
        return 0;
    }

    /* the roots */
    uint32_t *queue = malloc(g_decl_count * sizeof(uint32_t));
    int64_t *parent = malloc(g_decl_count * sizeof(int64_t));   /* the declaration that reached it, -1 for a root, -2 unreached */
    uint32_t *via = malloc(g_decl_count * sizeof(uint32_t));    /* the member constant it was reached by */
    uint32_t *origin = malloc(g_decl_count * sizeof(uint32_t)); /* the root member it was reached from */
    for (size_t i = 0; i < g_decl_count; i++) parent[i] = -2;
    size_t head = 0, tail = 0;
    char *roots = strdup(roots_text);
    for (char *r = strtok(roots, ","); r; r = strtok(NULL, ",")) {
        int64_t m = member_by_text(r);
        if (m < 0) { fprintf(stderr, "leanexport: no declaration %s\n", r); return 1; }
        uint32_t d = g_members[m].decl;
        if (parent[d] == -2) { parent[d] = -1; via[d] = (uint32_t)m; origin[d] = (uint32_t)m; queue[tail++] = d; }
    }

    /* breadth first, every expression walked once in all: a constant under an expression two declarations share was
       reached from the first of them, which names it as surely as the second, so walking it again finds nothing new.
       One bit an expression marks it. */
    uint8_t *seen = calloc(expr_total / 8 + 1, 1);
    if (!seen) { fprintf(stderr, "leanexport: out of memory\n"); return 1; }
    uint32_t *stack = NULL; size_t stack_capacity = 0;
    while (head < tail) {
        uint32_t d = queue[head++];
        Decl *decl = &g_decl_list[d];
        size_t top = 0;
        for (uint32_t k = 0; k < decl->root_count; k++) {
            if (top == stack_capacity) { stack_capacity = stack_capacity ? 2 * stack_capacity : 1 << 16; stack = realloc(stack, stack_capacity * sizeof(uint32_t)); }
            stack[top++] = g_expr_roots[decl->first_root + k];
        }
        while (top) {
            uint32_t e = stack[--top];
            if (e >= expr_total) { fprintf(stderr, "leanexport: expression %u out of range\n", e); return 1; }
            if (seen[e >> 3] & (1u << (e & 7))) continue;
            seen[e >> 3] |= (uint8_t)(1u << (e & 7));
            uint32_t row[5];
            expr_row(e, row);
            uint32_t children[3], count = 0;
            switch (row[0]) {
                case 2: {
                    int64_t m = member_of_name(row[1]);
                    if (m < 0) { char *n = name_string(row[1]); fprintf(stderr, "leanexport: %s is used but not declared\n", n); free(n); return 1; }
                    uint32_t target = g_members[m].decl;
                    if (parent[target] == -2) { parent[target] = d; via[target] = (uint32_t)m; origin[target] = origin[d]; queue[tail++] = target; }
                    break;
                }
                case 3: children[count++] = row[1]; children[count++] = row[2]; break;
                case 4: case 5: children[count++] = row[2]; children[count++] = row[3]; break;
                case 6: children[count++] = row[2]; children[count++] = row[3]; children[count++] = row[4]; break;
                case 9: children[count++] = row[3]; break;
                default: break;
            }
            for (uint32_t c = 0; c < count; c++) {
                if (top == stack_capacity) { stack_capacity *= 2; stack = realloc(stack, stack_capacity * sizeof(uint32_t)); }
                stack[top++] = children[c];
            }
        }
    }

    /* the cone, in the export's order */
    FILE *out = fopen(out_path, "w");
    if (!out) { fprintf(stderr, "leanexport: cannot write %s\n", out_path); return 1; }
    uint64_t by_kind[8] = {0}, members_in = 0;
    fprintf(out, "name\tkind\troot\n");
    for (size_t d = 0; d < g_decl_count; d++) {
        if (parent[d] == -2) continue;
        char *root = name_string(g_members[origin[d]].name);
        for (uint32_t k = 0; k < g_decl_list[d].member_count; k++) {
            Member *m = &g_members[g_decl_list[d].first_member + k];
            char *n = name_string(m->name);
            fprintf(out, "%s\t%s\t%s\n", n, kind_names[m->kind], root);
            free(n);
            by_kind[m->kind]++;
            members_in++;
        }
        free(root);
    }
    fclose(out);
    printf("cone: %llu declarations, %llu constants:", (unsigned long long)tail, (unsigned long long)members_in);
    for (int k = 0; k < 8; k++) printf(" %s %llu", kind_names[k], (unsigned long long)by_kind[k]);
    printf("\n");

    /* the targets, each with one path from a root */
    if (targets_text) {
        char *targets = strdup(targets_text);
        for (char *t = strtok(targets, ","); t; t = strtok(NULL, ",")) {
            int64_t m = member_by_text(t);
            if (m < 0) { printf("%s\tnot declared in the export\n", t); continue; }
            uint32_t d = g_members[m].decl;
            if (parent[d] == -2) { printf("%s\tnot in the cone\n", t); continue; }
            /* the path, from the target up to its root, printed root first */
            size_t steps = 0;
            uint32_t *path_members = malloc(g_decl_count * sizeof(uint32_t));
            path_members[steps++] = (uint32_t)m;
            for (int64_t x = d; parent[x] >= 0; x = parent[x]) path_members[steps++] = via[parent[x]];
            printf("%s\tin the cone, %zu steps:", t, steps - 1);
            for (size_t s = steps; s-- > 0;) { char *n = name_string(g_members[path_members[s]].name); printf(" %s%s", n, s ? " ->" : ""); free(n); }
            printf("\n");
            free(path_members);
        }
        free(targets);
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "convert") == 0) return convert(argv[2]);
    if ((argc == 5 || argc == 6) && strcmp(argv[1], "cone") == 0) return cone(argv[2], argv[3], argv[4], argc == 6 ? argv[5] : NULL);
    fprintf(stderr, "usage: leanexport convert OUTDIR < export.ndjson\n       leanexport cone OUTDIR CONE.tsv root,root,... [target,target,...]\n");
    return 2;
}
