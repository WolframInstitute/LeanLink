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
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
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

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "convert") == 0) return convert(argv[2]);
    fprintf(stderr, "usage: leanexport convert OUTDIR < export.ndjson\n");
    return 2;
}
