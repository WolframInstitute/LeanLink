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
 *
 * Per-declaration direct references, using a lazy summary cache on cross-declaration shared expressions (one u32 per
 * expression), verifying export order and optionally writing a CSR binary file (u64 decl_count, u64 offsets[N+1],
 * u32 targets[E]):
 *
 *     leanexport deps OUTDIR [DEPS.bin]
 *
 * A self-contained WXF slice for LeanLink's TypeTheory bridge (Order, Constants, Inductives, and the shim's fields
 * Table), with no Lean in the path:
 *
 *     leanexport slice OUTDIR SLICE.wxf [--axiomatize-theorems] [--proofs-for LIST] [--exclude LIST] ROOTS
 *     leanexport slice-batch OUTDIR MANIFEST
 *
 * LIST and ROOTS are comma-separated constant names or @path (one name per line). With --axiomatize-theorems, every
 * theorem is walked by type alone and emitted as an axiom; with --proofs-for, only those theorems carry proofs and all
 * other reached theorems are axiomatized; --exclude stops the walk at declarations already in a base environment.
 * slice-batch loads the export once and processes one shard per line of MANIFEST (or "-" for stdin), each line taking
 * the same arguments as slice after OUTDIR.
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
    size_t capacity = b->capacity ? b->capacity : 64;
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

static Mapped t_names, t_levels, t_exprs, t_depths, t_lists, t_lists_idx, t_strings, t_strings_idx;

static uint8_t name_kind(uint32_t id) { return t_names.data[(size_t)id * 16]; }

static uint32_t name_prefix(uint32_t id) { uint32_t v; memcpy(&v, t_names.data + (size_t)id * 16 + 4, 4); return v; }

static uint64_t name_value(uint32_t id) { uint64_t v; memcpy(&v, t_names.data + (size_t)id * 16 + 8, 8); return v; }

static void level_row(uint32_t id, uint32_t row[3]) { memcpy(row, t_levels.data + (size_t)id * 12, 12); }

static const uint32_t *level_list_at(uint32_t id, uint32_t *count) {
    uint64_t offset; uint32_t n;
    memcpy(&offset, t_lists_idx.data + (size_t)id * 12, 8);
    memcpy(&n, t_lists_idx.data + (size_t)id * 12 + 8, 4);
    *count = n;
    return (const uint32_t *)(t_lists.data + offset * 4);
}

static const char *string_at(uint64_t id, uint32_t *length) {
    uint64_t offset; uint32_t n;
    memcpy(&offset, t_strings_idx.data + id * 12, 8);
    memcpy(&n, t_strings_idx.data + id * 12 + 8, 4);
    *length = n;
    return (const char *)t_strings.data + offset;
}

static void expr_row(uint32_t id, uint32_t row[5]) { memcpy(row, t_exprs.data + (size_t)id * 20, 20); }

static uint32_t expr_depth(uint32_t id) { uint32_t v; memcpy(&v, t_depths.data + (size_t)id * 4, 4); return v; }

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
static const char *bridge_kind_names[] = {"theorem", "def", "opaque", "axiom", "quot", "inductive", "constructor", "recursor"};

typedef struct {
    uint32_t name;
    uint8_t kind;
    uint32_t decl;
    uint32_t type_expr;
    int64_t val_expr;              /* -1 when the constant has no value */
    uint32_t first_lparam, lparam_count;
} Member;

typedef struct {
    uint32_t member;
    uint32_t num_params, num_nested;
    uint32_t first_all, all_count;
    uint32_t first_ctor, ctor_count;
} IndType;

typedef struct {
    uint8_t kind;
    uint32_t first_member, member_count;   /* its constants, in members */
    uint32_t first_root, root_count;       /* all expressions for cone, in expr_roots */
    uint32_t first_type_root, type_root_count; /* types (and ctors for inductive) */
    uint32_t first_val_root, val_root_count;   /* value (or rec types + rules for inductive) */
    int32_t first_ind;                     /* first entry in g_ind_types, or -1 */
    uint32_t ind_count;
} Decl;

static Member *g_members; static size_t g_member_count, g_member_capacity;
static uint32_t *g_lparams; static size_t g_lparam_count, g_lparam_capacity;
static uint32_t *g_ind_names; static size_t g_ind_name_count, g_ind_name_capacity;
static IndType *g_ind_types; static size_t g_ind_type_count, g_ind_type_capacity;
static uint32_t *g_expr_roots; static size_t g_expr_root_count, g_expr_root_capacity;
static uint32_t *g_type_roots; static size_t g_type_root_count, g_type_root_capacity;
static uint32_t *g_val_roots; static size_t g_val_root_count, g_val_root_capacity;
static Decl *g_decl_list; static size_t g_decl_count, g_decl_capacity;

static void push_u32(uint32_t **arr, size_t *count, size_t *cap, uint32_t v) {
    if (*count == *cap) { *cap = *cap ? 2 * (*cap) : 1 << 16; *arr = realloc(*arr, (*cap) * sizeof(uint32_t)); if (!*arr) fail("out of memory"); }
    (*arr)[(*count)++] = v;
}

static uint32_t push_member(uint32_t name, uint8_t kind, uint32_t type_expr, int64_t val_expr, const Json *lparams) {
    if (g_member_count == g_member_capacity) { g_member_capacity = g_member_capacity ? 2 * g_member_capacity : 1 << 16; g_members = realloc(g_members, g_member_capacity * sizeof(Member)); if (!g_members) fail("out of memory"); }
    uint32_t first_lp = (uint32_t)g_lparam_count;
    if (lparams && lparams->type == J_ARRAY)
        for (Json *p = lparams->child; p; p = p->next) push_u32(&g_lparams, &g_lparam_count, &g_lparam_capacity, index32((uint64_t)p->number));
    uint32_t idx = (uint32_t)g_member_count++;
    g_members[idx] = (Member){name, kind, (uint32_t)g_decl_count, type_expr, val_expr, first_lp, (uint32_t)g_lparam_count - first_lp};
    return idx;
}

static void push_root(uint64_t expr) { push_u32(&g_expr_roots, &g_expr_root_count, &g_expr_root_capacity, index32(expr)); }

static uint32_t add_constant(const Json *c, uint8_t kind, int type_as_val) {
    uint32_t ty = index32(require_index(c, "type"));
    Json *value = member(c, "value");
    int64_t val = value ? value->number : -1;
    uint32_t midx = push_member(index32(require_index(c, "name")), kind, ty, val, member(c, "levelParams"));
    push_root(ty);
    if (type_as_val) push_u32(&g_val_roots, &g_val_root_count, &g_val_root_capacity, ty);
    else push_u32(&g_type_roots, &g_type_root_count, &g_type_root_capacity, ty);
    if (value) {
        push_root((uint64_t)val);
        push_u32(&g_val_roots, &g_val_root_count, &g_val_root_capacity, index32((uint64_t)val));
    }
    return midx;
}

static void read_decl(const Json *line) {
    if (g_decl_count == g_decl_capacity) { g_decl_capacity = g_decl_capacity ? 2 * g_decl_capacity : 1 << 16; g_decl_list = realloc(g_decl_list, g_decl_capacity * sizeof(Decl)); if (!g_decl_list) fail("out of memory"); }
    Decl d = {0, (uint32_t)g_member_count, 0, (uint32_t)g_expr_root_count, 0, (uint32_t)g_type_root_count, 0, (uint32_t)g_val_root_count, 0, -1, 0};
    static const char *simple[] = {"thm", "def", "opaque", "axiom", "quot"};
    static const uint8_t simple_kinds[] = {K_THEOREM, K_DEFINITION, K_OPAQUE, K_AXIOM, K_QUOT};
    Json *m = NULL;
    for (int i = 0; i < 5; i++) if ((m = member(line, simple[i]))) { d.kind = simple_kinds[i]; add_constant(m, simple_kinds[i], 0); break; }
    if (!m) {
        d.kind = K_INDUCTIVE;
        d.first_ind = (int32_t)g_ind_type_count;
        Json *block = require(line, "inductive");
        for (Json *t = require(block, "types")->child; t; t = t->next) {
            uint32_t midx = add_constant(t, K_INDUCTIVE, 0);
            if (g_ind_type_count == g_ind_type_capacity) { g_ind_type_capacity = g_ind_type_capacity ? 2 * g_ind_type_capacity : 4096; g_ind_types = realloc(g_ind_types, g_ind_type_capacity * sizeof(IndType)); if (!g_ind_types) fail("out of memory"); }
            IndType it = {midx, index32(require_index(t, "numParams")), index32(require_index(t, "numNested")), (uint32_t)g_ind_name_count, 0, 0, 0};
            for (Json *a = require(t, "all")->child; a; a = a->next) push_u32(&g_ind_names, &g_ind_name_count, &g_ind_name_capacity, index32((uint64_t)a->number));
            it.all_count = (uint32_t)g_ind_name_count - it.first_all;
            it.first_ctor = (uint32_t)g_ind_name_count;
            for (Json *c = require(t, "ctors")->child; c; c = c->next) push_u32(&g_ind_names, &g_ind_name_count, &g_ind_name_capacity, index32((uint64_t)c->number));
            it.ctor_count = (uint32_t)g_ind_name_count - it.first_ctor;
            g_ind_types[g_ind_type_count++] = it;
        }
        d.ind_count = (uint32_t)g_ind_type_count - (uint32_t)d.first_ind;
        for (Json *c = require(block, "ctors")->child; c; c = c->next) add_constant(c, K_CONSTRUCTOR, 0);
        for (Json *r = require(block, "recs")->child; r; r = r->next) {
            add_constant(r, K_RECURSOR, 1);
            for (Json *rule = require(r, "rules")->child; rule; rule = rule->next) {
                uint64_t rhs = require_index(rule, "rhs");
                push_root(rhs);
                push_u32(&g_val_roots, &g_val_root_count, &g_val_root_capacity, index32(rhs));
            }
        }
    }
    d.member_count = (uint32_t)g_member_count - d.first_member;
    d.root_count = (uint32_t)g_expr_root_count - d.first_root;
    d.type_root_count = (uint32_t)g_type_root_count - d.first_type_root;
    d.val_root_count = (uint32_t)g_val_root_count - d.first_val_root;
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

static int load_decls_and_names(const char *dir, int map_all_tables) {
    t_names = map_file(dir, "names.bin");
    t_exprs = map_file(dir, "exprs.bin");
    t_strings = map_file(dir, "strings.bin");
    t_strings_idx = map_file(dir, "strings.idx");
    if (map_all_tables) {
        t_levels = map_file(dir, "levels.bin");
        t_depths = map_file(dir, "depths.bin");
        t_lists = map_file(dir, "levellists.bin");
        t_lists_idx = map_file(dir, "levellists.idx");
    }
    g_name_total = t_names.size / 16;

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
    if (!g_by_name) fail("out of memory");
    for (size_t i = 0; i < g_name_total; i++) g_by_name[i] = -1;
    g_named = malloc(g_member_count * sizeof(NamedMember));
    if (!g_named) fail("out of memory");
    for (size_t i = 0; i < g_member_count; i++) {
        g_by_name[g_members[i].name] = (int64_t)i;
        g_named[i] = (NamedMember){name_string(g_members[i].name), (uint32_t)i};
    }
    g_named_count = g_member_count;
    qsort(g_named, g_named_count, sizeof(NamedMember), compare_named);
    return 0;
}

/* ---------- the cone ---------- */

static int cone(const char *dir, const char *out_path, const char *roots_text, const char *targets_text) {
    if (load_decls_and_names(dir, 0) != 0) return 1;
    size_t expr_total = t_exprs.size / 20;

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

/* ---------- per-declaration direct dependencies ---------- */

typedef struct { uint32_t *keys; uint32_t mask, count; } U32Set;

static void u32set_init(U32Set *s, uint32_t cap) {
    s->keys = malloc(cap * sizeof(uint32_t));
    if (!s->keys) fail("out of memory");
    memset(s->keys, 0xFF, cap * sizeof(uint32_t));
    s->mask = cap - 1;
    s->count = 0;
}

static void u32set_clear(U32Set *s, uint32_t *touched, uint32_t n) {
    for (uint32_t i = 0; i < n; i++) s->keys[touched[i]] = UINT32_MAX;
    s->count = 0;
}

static void u32set_grow(U32Set *s, uint32_t **touched, size_t *tcap, uint32_t *tlen) {
    uint32_t old_cap = s->mask + 1, new_cap = old_cap * 2;
    uint32_t *nk = malloc(new_cap * sizeof(uint32_t));
    if (!nk) fail("out of memory");
    memset(nk, 0xFF, new_cap * sizeof(uint32_t));
    uint32_t nmask = new_cap - 1;
    for (uint32_t i = 0; i < old_cap; i++) {
        uint32_t k = s->keys[i];
        if (k != UINT32_MAX) {
            uint32_t h = (k * 2654435761u) & nmask;
            while (nk[h] != UINT32_MAX) h = (h + 1) & nmask;
            nk[h] = k;
        }
    }
    free(s->keys);
    s->keys = nk;
    s->mask = nmask;
    if (new_cap > *tcap) {
        *tcap = new_cap;
        *touched = realloc(*touched, *tcap * sizeof(uint32_t));
        if (!*touched) fail("out of memory");
    }
    *tlen = 0;
    for (uint32_t i = 0; i <= nmask; i++) if (nk[i] != UINT32_MAX) (*touched)[(*tlen)++] = i;
}

static int u32set_insert(U32Set *s, uint32_t k, uint32_t **touched, size_t *tcap, uint32_t *tlen) {
    if ((s->count + 1) * 2 > s->mask + 1) u32set_grow(s, touched, tcap, tlen);
    uint32_t h = (k * 2654435761u) & s->mask;
    while (s->keys[h] != UINT32_MAX) {
        if (s->keys[h] == k) return 0;
        h = (h + 1) & s->mask;
    }
    s->keys[h] = k;
    s->count++;
    (*touched)[(*tlen)++] = h;
    return 1;
}

typedef struct { uint64_t off; uint32_t len; } Span;

static int compare_u32(const void *a, const void *b) {
    uint32_t x = *(const uint32_t *)a, y = *(const uint32_t *)b;
    return (x > y) - (x < y);
}

static int deps_cmd(const char *dir, const char *out_path) {
    if (load_decls_and_names(dir, 0) != 0) return 1;
    size_t expr_total = t_exprs.size / 20;
    if (g_decl_count >= 0x7FFFFFFFu) { fprintf(stderr, "leanexport: too many declarations\n"); return 1; }

    /* string-literal constants, if present in the export */
    static const char *str_const_names[5] = {"String.ofList", "List.cons", "List.nil", "Char.ofNat", "Char"};
    uint32_t str_decls[5]; int str_decl_count = 0;
    for (int i = 0; i < 5; i++) {
        int64_t m = member_by_text(str_const_names[i]);
        if (m >= 0) str_decls[str_decl_count++] = g_members[m].decl;
    }

    /* state[e]: 0 unvisited, 1..D visited only by decl d = state[e]-1,
       0x80000000 empty summary, 0x80000001..0xBFFFFFFF 1-decl summary (val - 0x80000001),
       0xC0000000|idx multi-decl summary in spans[idx] */
    uint32_t *state = calloc(expr_total, sizeof(uint32_t));
    uint32_t *dep_stamp = calloc(g_decl_count, sizeof(uint32_t));
    uint32_t *sub_dep_stamp = calloc(g_decl_count, sizeof(uint32_t));
    if (!state || !dep_stamp || !sub_dep_stamp) fail("out of memory");

    Span *spans = NULL; size_t span_count = 0, span_cap = 0;
    uint32_t *sdata = NULL; size_t sdata_count = 0, sdata_cap = 0;
    uint32_t *stack = malloc((1 << 16) * sizeof(uint32_t)); size_t stack_cap = 1 << 16;
    uint32_t *sub_stack = malloc((1 << 16) * sizeof(uint32_t)); size_t sub_cap = 1 << 16;
    U32Set sub_seen; u32set_init(&sub_seen, 1024);
    size_t stouched_cap = 1024; uint32_t *stouched = malloc(stouched_cap * sizeof(uint32_t));
    uint32_t *sub_deps = NULL; size_t sub_deps_cap = 0;
    uint32_t *cur_deps = NULL; size_t cur_deps_cap = 0;
    uint64_t *offsets = out_path ? malloc((g_decl_count + 1) * sizeof(uint64_t)) : NULL;
    uint32_t *all_edges = NULL; size_t all_edges_count = 0, all_edges_cap = 0;
    uint32_t sub_gen = 0;
    uint64_t total_edges = 0, backward_edges = 0, str_literal_decls = 0, summaries = 0;

    for (uint32_t d = 0; d < g_decl_count; d++) {
        uint32_t st = d + 1;
        Decl *decl = &g_decl_list[d];
        size_t top = 0, cur_len = 0;
        int has_str = 0;
        for (uint32_t k = 0; k < decl->root_count; k++) {
            if (top == stack_cap) { stack_cap *= 2; stack = realloc(stack, stack_cap * sizeof(uint32_t)); if (!stack) fail("out of memory"); }
            stack[top++] = g_expr_roots[decl->first_root + k];
        }
        while (top) {
            uint32_t e = stack[--top];
            if (e >= expr_total) { fprintf(stderr, "leanexport: expression %u out of range\n", e); return 1; }
            uint32_t sv = state[e];
            if (sv == st) continue;
            if (sv & 0x80000000u) {
                if (sv == 0x80000000u) continue;
                if ((sv & 0xC0000000u) == 0x80000000u) {
                    uint32_t target = (sv & 0x3FFFFFFFu) - 1;
                    if (target != d && dep_stamp[target] != st) {
                        dep_stamp[target] = st;
                        if (cur_len == cur_deps_cap) { cur_deps_cap = cur_deps_cap ? 2 * cur_deps_cap : 256; cur_deps = realloc(cur_deps, cur_deps_cap * sizeof(uint32_t)); }
                        cur_deps[cur_len++] = target;
                    }
                } else {
                    Span sp = spans[sv & 0x3FFFFFFFu];
                    const uint32_t *arr = sdata + sp.off;
                    for (uint32_t i = 0; i < sp.len; i++) {
                        uint32_t target = arr[i];
                        if (target != d && dep_stamp[target] != st) {
                            dep_stamp[target] = st;
                            if (cur_len == cur_deps_cap) { cur_deps_cap = cur_deps_cap ? 2 * cur_deps_cap : 256; cur_deps = realloc(cur_deps, cur_deps_cap * sizeof(uint32_t)); }
                            cur_deps[cur_len++] = target;
                        }
                    }
                }
                continue;
            }
            if (sv != 0) {
                summaries++;
                sub_gen++;
                uint32_t tlen = 0, sd_len = 0;
                size_t stop = 0;
                sub_stack[stop++] = e;
                u32set_insert(&sub_seen, e, &stouched, &stouched_cap, &tlen);
                while (stop) {
                    uint32_t x = sub_stack[--stop];
                    uint32_t xsv = state[x];
                    if (x != e && (xsv & 0x80000000u)) {
                        if (xsv == 0x80000000u) continue;
                        if ((xsv & 0xC0000000u) == 0x80000000u) {
                            uint32_t target = (xsv & 0x3FFFFFFFu) - 1;
                            if (sub_dep_stamp[target] != sub_gen) {
                                sub_dep_stamp[target] = sub_gen;
                                if (sd_len == sub_deps_cap) { sub_deps_cap = sub_deps_cap ? 2 * sub_deps_cap : 256; sub_deps = realloc(sub_deps, sub_deps_cap * sizeof(uint32_t)); }
                                sub_deps[sd_len++] = target;
                            }
                        } else {
                            Span sp = spans[xsv & 0x3FFFFFFFu];
                            const uint32_t *arr = sdata + sp.off;
                            for (uint32_t i = 0; i < sp.len; i++) {
                                uint32_t target = arr[i];
                                if (sub_dep_stamp[target] != sub_gen) {
                                    sub_dep_stamp[target] = sub_gen;
                                    if (sd_len == sub_deps_cap) { sub_deps_cap = sub_deps_cap ? 2 * sub_deps_cap : 256; sub_deps = realloc(sub_deps, sub_deps_cap * sizeof(uint32_t)); }
                                    sub_deps[sd_len++] = target;
                                }
                            }
                        }
                        continue;
                    }
                    uint32_t row[5], ch[3], nc = 0;
                    expr_row(x, row);
                    switch (row[0]) {
                        case 2: {
                            int64_t m = member_of_name(row[1]);
                            if (m < 0) { char *n = name_string(row[1]); fprintf(stderr, "leanexport: %s is used but not declared\n", n); free(n); return 1; }
                            uint32_t target = g_members[m].decl;
                            if (sub_dep_stamp[target] != sub_gen) {
                                sub_dep_stamp[target] = sub_gen;
                                if (sd_len == sub_deps_cap) { sub_deps_cap = sub_deps_cap ? 2 * sub_deps_cap : 256; sub_deps = realloc(sub_deps, sub_deps_cap * sizeof(uint32_t)); }
                                sub_deps[sd_len++] = target;
                            }
                            break;
                        }
                        case 8:
                            for (int i = 0; i < str_decl_count; i++) {
                                uint32_t target = str_decls[i];
                                if (sub_dep_stamp[target] != sub_gen) {
                                    sub_dep_stamp[target] = sub_gen;
                                    if (sd_len == sub_deps_cap) { sub_deps_cap = sub_deps_cap ? 2 * sub_deps_cap : 256; sub_deps = realloc(sub_deps, sub_deps_cap * sizeof(uint32_t)); }
                                    sub_deps[sd_len++] = target;
                                }
                            }
                            break;
                        case 3: ch[nc++] = row[1]; ch[nc++] = row[2]; break;
                        case 4: case 5: ch[nc++] = row[2]; ch[nc++] = row[3]; break;
                        case 6: ch[nc++] = row[2]; ch[nc++] = row[3]; ch[nc++] = row[4]; break;
                        case 9: ch[nc++] = row[3]; break;
                        default: break;
                    }
                    for (uint32_t i = 0; i < nc; i++) {
                        if (u32set_insert(&sub_seen, ch[i], &stouched, &stouched_cap, &tlen)) {
                            if (stop == sub_cap) { sub_cap *= 2; sub_stack = realloc(sub_stack, sub_cap * sizeof(uint32_t)); if (!sub_stack) fail("out of memory"); }
                            sub_stack[stop++] = ch[i];
                        }
                    }
                }
                u32set_clear(&sub_seen, stouched, tlen);
                if (sd_len == 0) state[e] = 0x80000000u;
                else if (sd_len == 1) state[e] = 0x80000000u | (sub_deps[0] + 1);
                else {
                    if (span_count >= 0x3FFFFFFFu) fail("too many shared summaries");
                    if (span_count == span_cap) { span_cap = span_cap ? 2 * span_cap : 1 << 14; spans = realloc(spans, span_cap * sizeof(Span)); if (!spans) fail("out of memory"); }
                    if (sdata_count + sd_len > sdata_cap) {
                        sdata_cap = sdata_cap ? sdata_cap * 2 : 1 << 16;
                        while (sdata_cap < sdata_count + sd_len) sdata_cap *= 2;
                        sdata = realloc(sdata, sdata_cap * sizeof(uint32_t));
                        if (!sdata) fail("out of memory");
                    }
                    memcpy(sdata + sdata_count, sub_deps, sd_len * sizeof(uint32_t));
                    spans[span_count] = (Span){sdata_count, sd_len};
                    sdata_count += sd_len;
                    state[e] = 0xC0000000u | (uint32_t)span_count++;
                }
                for (uint32_t i = 0; i < sd_len; i++) {
                    uint32_t target = sub_deps[i];
                    if (target != d && dep_stamp[target] != st) {
                        dep_stamp[target] = st;
                        if (cur_len == cur_deps_cap) { cur_deps_cap = cur_deps_cap ? 2 * cur_deps_cap : 256; cur_deps = realloc(cur_deps, cur_deps_cap * sizeof(uint32_t)); }
                        cur_deps[cur_len++] = target;
                    }
                }
                continue;
            }
            state[e] = st;
            uint32_t row[5], ch[3], nc = 0;
            expr_row(e, row);
            switch (row[0]) {
                case 2: {
                    int64_t m = member_of_name(row[1]);
                    if (m < 0) { char *n = name_string(row[1]); fprintf(stderr, "leanexport: %s is used but not declared\n", n); free(n); return 1; }
                    uint32_t target = g_members[m].decl;
                    if (target != d && dep_stamp[target] != st) {
                        dep_stamp[target] = st;
                        if (cur_len == cur_deps_cap) { cur_deps_cap = cur_deps_cap ? 2 * cur_deps_cap : 256; cur_deps = realloc(cur_deps, cur_deps_cap * sizeof(uint32_t)); }
                        cur_deps[cur_len++] = target;
                    }
                    break;
                }
                case 8:
                    has_str = 1;
                    for (int i = 0; i < str_decl_count; i++) {
                        uint32_t target = str_decls[i];
                        if (target != d && dep_stamp[target] != st) {
                            dep_stamp[target] = st;
                            if (cur_len == cur_deps_cap) { cur_deps_cap = cur_deps_cap ? 2 * cur_deps_cap : 256; cur_deps = realloc(cur_deps, cur_deps_cap * sizeof(uint32_t)); }
                            cur_deps[cur_len++] = target;
                        }
                    }
                    break;
                case 3: ch[nc++] = row[1]; ch[nc++] = row[2]; break;
                case 4: case 5: ch[nc++] = row[2]; ch[nc++] = row[3]; break;
                case 6: ch[nc++] = row[2]; ch[nc++] = row[3]; ch[nc++] = row[4]; break;
                case 9: ch[nc++] = row[3]; break;
                default: break;
            }
            for (uint32_t i = 0; i < nc; i++) {
                if (top == stack_cap) { stack_cap *= 2; stack = realloc(stack, stack_cap * sizeof(uint32_t)); if (!stack) fail("out of memory"); }
                stack[top++] = ch[i];
            }
        }
        if (has_str) str_literal_decls++;
        for (size_t i = 0; i < cur_len; i++) if (cur_deps[i] > d) backward_edges++;
        total_edges += cur_len;
        if (out_path) {
            qsort(cur_deps, cur_len, sizeof(uint32_t), compare_u32);
            offsets[d] = all_edges_count;
            if (all_edges_count + cur_len > all_edges_cap) {
                all_edges_cap = all_edges_cap ? all_edges_cap * 2 : 1 << 16;
                while (all_edges_cap < all_edges_count + cur_len) all_edges_cap *= 2;
                all_edges = realloc(all_edges, all_edges_cap * sizeof(uint32_t));
                if (!all_edges) fail("out of memory");
            }
            if (cur_len) memcpy(all_edges + all_edges_count, cur_deps, cur_len * sizeof(uint32_t));
            all_edges_count += cur_len;
        }
    }
    if (out_path) {
        offsets[g_decl_count] = all_edges_count;
        FILE *f = fopen(out_path, "wb");
        if (!f) { fprintf(stderr, "leanexport: cannot write %s: %s\n", out_path, strerror(errno)); return 1; }
        setvbuf(f, NULL, _IOFBF, 1 << 22);
        uint64_t n = g_decl_count;
        fwrite(&n, 8, 1, f);
        fwrite(offsets, 8, g_decl_count + 1, f);
        if (all_edges_count) fwrite(all_edges, 4, all_edges_count, f);
        if (fclose(f) != 0) fail("a write failed");
    }
    printf("deps: %zu declarations, %llu edges, %llu backward, %llu with string literals; %llu shared summaries (%.2f MB)\n",
        g_decl_count, (unsigned long long)total_edges, (unsigned long long)backward_edges,
        (unsigned long long)str_literal_decls, (unsigned long long)summaries,
        (double)(sdata_count * 4 + span_count * sizeof(Span)) / (1024.0 * 1024.0));
    return 0;
}

/* ---------- WXF writer for slice ---------- */

static void wxf_varint(FILE *f, uint64_t n) {
    while (n >= 128) { fputc((int)((n & 0x7Fu) | 0x80u), f); n >>= 7; }
    fputc((int)n, f);
}

static void wxf_symbol(FILE *f, const char *s) {
    size_t n = strlen(s);
    fputc('s', f); wxf_varint(f, n); fwrite(s, 1, n, f);
}

static void wxf_string_n(FILE *f, const char *s, size_t n) {
    fputc('S', f); wxf_varint(f, n); fwrite(s, 1, n, f);
}

static void wxf_string(FILE *f, const char *s) { wxf_string_n(f, s, strlen(s)); }

static void wxf_list_head(FILE *f, size_t count) {
    fputc('f', f); wxf_varint(f, count); wxf_symbol(f, "List");
}

static void wxf_assoc_head(FILE *f, size_t count) {
    fputc('A', f); wxf_varint(f, count);
}

static void wxf_int(FILE *f, int64_t n) {
    if (n >= -128 && n <= 127) {
        int8_t v = (int8_t)n; fputc('C', f); fwrite(&v, 1, 1, f);
    } else if (n >= -32768 && n <= 32767) {
        int16_t v = (int16_t)n; fputc('j', f); fwrite(&v, 2, 1, f);
    } else if (n >= -2147483648LL && n <= 2147483647LL) {
        int32_t v = (int32_t)n; fputc('i', f); fwrite(&v, 4, 1, f);
    } else {
        fputc('L', f); fwrite(&n, 8, 1, f);
    }
}

static void wxf_nat_digits(FILE *f, const char *digits, size_t len) {
    if (len <= 18) {
        int64_t v = 0;
        for (size_t i = 0; i < len; i++) v = v * 10 + (digits[i] - '0');
        wxf_int(f, v);
    } else {
        fputc('I', f); wxf_varint(f, len); fwrite(digits, 1, len, f);
    }
}

static void wxf_packed_i32_1d(FILE *f, const uint32_t *data, size_t d0) {
    if (d0 == 0) { wxf_list_head(f, 0); return; }
    fputc(193, f); fputc(2, f);
    wxf_varint(f, 1); wxf_varint(f, d0);
    fwrite(data, 4, d0, f);
}

static void wxf_packed_i32_2d(FILE *f, const uint32_t *data, size_t d0, size_t d1) {
    if (d0 == 0 || d1 == 0) { wxf_list_head(f, 0); return; }
    fputc(193, f); fputc(2, f);
    wxf_varint(f, 2); wxf_varint(f, d0); wxf_varint(f, d1);
    fwrite(data, 4, d0 * d1, f);
}

/* ---------- open-addressing u32 -> u32 map (value 0 = absent, key UINT32_MAX = empty slot) ---------- */

typedef struct { uint32_t *keys, *vals; uint32_t mask, count; } U32Map;

static void u32map_init(U32Map *m, uint32_t cap) {
    m->keys = malloc(cap * sizeof(uint32_t));
    m->vals = calloc(cap, sizeof(uint32_t));
    if (!m->keys || !m->vals) fail("out of memory");
    memset(m->keys, 0xFF, cap * sizeof(uint32_t));
    m->mask = cap - 1;
    m->count = 0;
}

static void u32map_grow(U32Map *m) {
    uint32_t old_cap = m->mask + 1, new_cap = old_cap * 2;
    uint32_t *nk = malloc(new_cap * sizeof(uint32_t));
    uint32_t *nv = calloc(new_cap, sizeof(uint32_t));
    if (!nk || !nv) fail("out of memory");
    memset(nk, 0xFF, new_cap * sizeof(uint32_t));
    uint32_t nmask = new_cap - 1;
    for (uint32_t i = 0; i < old_cap; i++) {
        uint32_t k = m->keys[i];
        if (k != UINT32_MAX) {
            uint32_t h = (k * 2654435761u) & nmask;
            while (nk[h] != UINT32_MAX) h = (h + 1) & nmask;
            nk[h] = k; nv[h] = m->vals[i];
        }
    }
    free(m->keys); free(m->vals);
    m->keys = nk; m->vals = nv; m->mask = nmask;
}

static uint32_t u32map_get(const U32Map *m, uint32_t k) {
    uint32_t h = (k * 2654435761u) & m->mask;
    while (m->keys[h] != UINT32_MAX) {
        if (m->keys[h] == k) return m->vals[h];
        h = (h + 1) & m->mask;
    }
    return 0;
}

static void u32map_put(U32Map *m, uint32_t k, uint32_t v) {
    if ((m->count + 1) * 2 > m->mask + 1) u32map_grow(m);
    uint32_t h = (k * 2654435761u) & m->mask;
    while (m->keys[h] != UINT32_MAX) {
        if (m->keys[h] == k) { m->vals[h] = v; return; }
        h = (h + 1) & m->mask;
    }
    m->keys[h] = k; m->vals[h] = v; m->count++;
}

/* ---------- slice remapping state ---------- */

typedef struct {
    U32Map expr_map, name_map, level_map, llist_map, nat_map, str_map;
    uint32_t *nodes; size_t node_count, node_cap;        /* 5 u32 per node */
    uint32_t *depths; size_t depth_cap;                  /* 1 u32 per node */
    uint32_t *names; size_t name_count, name_cap;        /* orig name_id */
    uint32_t *levels; size_t level_count, level_cap;     /* 3 u32 per level */
    uint32_t *ll_items; size_t ll_item_count, ll_item_cap;
    Span *ll_spans; size_t ll_count, ll_cap;
    uint32_t *nats; size_t nat_count, nat_cap;           /* orig string_id */
    uint32_t *strs; size_t str_count, str_cap;           /* orig string_id */
} SliceTable;

static void slice_table_init(SliceTable *t) {
    memset(t, 0, sizeof *t);
    u32map_init(&t->expr_map, 1 << 16);
    u32map_init(&t->name_map, 1 << 14);
    u32map_init(&t->level_map, 1 << 10);
    u32map_init(&t->llist_map, 1 << 12);
    u32map_init(&t->nat_map, 1 << 8);
    u32map_init(&t->str_map, 1 << 8);
}

static void u32map_free(U32Map *m) { free(m->keys); free(m->vals); m->keys = NULL; m->vals = NULL; }

static void slice_table_free(SliceTable *t) {
    u32map_free(&t->expr_map); u32map_free(&t->name_map); u32map_free(&t->level_map);
    u32map_free(&t->llist_map); u32map_free(&t->nat_map); u32map_free(&t->str_map);
    free(t->nodes); free(t->depths); free(t->names); free(t->levels);
    free(t->ll_items); free(t->ll_spans); free(t->nats); free(t->strs);
}

static uint32_t slice_name(SliceTable *t, uint32_t orig_name) {
    uint32_t v = u32map_get(&t->name_map, orig_name);
    if (v) return v;
    push_u32(&t->names, &t->name_count, &t->name_cap, orig_name);
    v = (uint32_t)t->name_count;
    u32map_put(&t->name_map, orig_name, v);
    return v;
}

static uint32_t slice_nat(SliceTable *t, uint32_t orig_str) {
    uint32_t v = u32map_get(&t->nat_map, orig_str);
    if (v) return v;
    push_u32(&t->nats, &t->nat_count, &t->nat_cap, orig_str);
    v = (uint32_t)t->nat_count;
    u32map_put(&t->nat_map, orig_str, v);
    return v;
}

static uint32_t slice_str(SliceTable *t, uint32_t orig_str) {
    uint32_t v = u32map_get(&t->str_map, orig_str);
    if (v) return v;
    push_u32(&t->strs, &t->str_count, &t->str_cap, orig_str);
    v = (uint32_t)t->str_count;
    u32map_put(&t->str_map, orig_str, v);
    return v;
}

static uint32_t slice_level(SliceTable *t, uint32_t orig_lvl) {
    uint32_t v = u32map_get(&t->level_map, orig_lvl);
    if (v) return v;
    uint32_t row[3], out[3];
    level_row(orig_lvl, row);
    out[0] = row[0]; out[1] = 0; out[2] = 0;
    if (row[0] == 1) out[1] = slice_level(t, row[1]);
    else if (row[0] == 2 || row[0] == 3) { out[1] = slice_level(t, row[1]); out[2] = slice_level(t, row[2]); }
    else if (row[0] == 4) out[1] = slice_name(t, row[1]);
    if (t->level_count == t->level_cap) {
        t->level_cap = t->level_cap ? 2 * t->level_cap : 1024;
        t->levels = realloc(t->levels, t->level_cap * 3 * sizeof(uint32_t));
        if (!t->levels) fail("out of memory");
    }
    memcpy(t->levels + t->level_count * 3, out, 12);
    v = (uint32_t)++t->level_count;
    u32map_put(&t->level_map, orig_lvl, v);
    return v;
}

static uint32_t slice_level_list(SliceTable *t, uint32_t orig_ll) {
    uint32_t v = u32map_get(&t->llist_map, orig_ll);
    if (v) return v;
    uint32_t count = 0;
    const uint32_t *lvls = level_list_at(orig_ll, &count);
    uint64_t off = t->ll_item_count;
    for (uint32_t i = 0; i < count; i++) push_u32(&t->ll_items, &t->ll_item_count, &t->ll_item_cap, slice_level(t, lvls[i]));
    if (t->ll_count == t->ll_cap) {
        t->ll_cap = t->ll_cap ? 2 * t->ll_cap : 4096;
        t->ll_spans = realloc(t->ll_spans, t->ll_cap * sizeof(Span));
        if (!t->ll_spans) fail("out of memory");
    }
    t->ll_spans[t->ll_count] = (Span){off, count};
    v = (uint32_t)++t->ll_count;
    u32map_put(&t->llist_map, orig_ll, v);
    return v;
}

typedef struct { uint32_t expr; uint8_t post; } PostFrame;

static uint32_t slice_expr(SliceTable *t, uint32_t root_expr, PostFrame **stack, size_t *stack_cap) {
    uint32_t existing = u32map_get(&t->expr_map, root_expr);
    if (existing) return existing;
    size_t top = 0;
    if (*stack_cap == 0) { *stack_cap = 1 << 16; *stack = malloc(*stack_cap * sizeof(PostFrame)); if (!*stack) fail("out of memory"); }
    (*stack)[top++] = (PostFrame){root_expr, 0};
    while (top) {
        PostFrame f = (*stack)[--top];
        uint32_t e = f.expr;
        if (u32map_get(&t->expr_map, e)) continue;
        uint32_t row[5];
        expr_row(e, row);
        if (!f.post) {
            uint32_t ch[3], nc = 0;
            switch (row[0]) {
                case 3: ch[nc++] = row[1]; ch[nc++] = row[2]; break;
                case 4: case 5: ch[nc++] = row[2]; ch[nc++] = row[3]; break;
                case 6: ch[nc++] = row[2]; ch[nc++] = row[3]; ch[nc++] = row[4]; break;
                case 9: ch[nc++] = row[3]; break;
                default: break;
            }
            if (nc > 0) {
                if (top + nc + 1 > *stack_cap) { *stack_cap *= 2; *stack = realloc(*stack, *stack_cap * sizeof(PostFrame)); if (!*stack) fail("out of memory"); }
                (*stack)[top++] = (PostFrame){e, 1};
                for (uint32_t i = nc; i-- > 0;)
                    if (!u32map_get(&t->expr_map, ch[i])) (*stack)[top++] = (PostFrame){ch[i], 0};
                continue;
            }
        }
        uint32_t out[5] = {row[0], 0, 0, 0, 0};
        switch (row[0]) {
            case 0: out[1] = row[1]; break;
            case 1: out[1] = slice_level(t, row[1]); break;
            case 2: out[1] = slice_name(t, row[1]); out[2] = slice_level_list(t, row[2]); break;
            case 3: out[1] = u32map_get(&t->expr_map, row[1]); out[2] = u32map_get(&t->expr_map, row[2]); break;
            case 4: case 5:
                out[1] = slice_name(t, row[1]);
                out[2] = u32map_get(&t->expr_map, row[2]);
                out[3] = u32map_get(&t->expr_map, row[3]);
                out[4] = row[4];
                break;
            case 6:
                out[1] = slice_name(t, row[1]);
                out[2] = u32map_get(&t->expr_map, row[2]);
                out[3] = u32map_get(&t->expr_map, row[3]);
                out[4] = u32map_get(&t->expr_map, row[4]);
                break;
            case 7: out[1] = slice_nat(t, row[1]); break;
            case 8: out[1] = slice_str(t, row[1]); break;
            case 9: out[1] = slice_name(t, row[1]); out[2] = row[2]; out[3] = u32map_get(&t->expr_map, row[3]); break;
            default: fail("unknown expression kind in slice");
        }
        if (t->node_count == t->node_cap) {
            t->node_cap = t->node_cap ? 2 * t->node_cap : 1 << 16;
            t->nodes = realloc(t->nodes, t->node_cap * 5 * sizeof(uint32_t));
            t->depths = realloc(t->depths, t->node_cap * sizeof(uint32_t));
            if (!t->nodes || !t->depths) fail("out of memory");
        }
        memcpy(t->nodes + t->node_count * 5, out, 20);
        t->depths[t->node_count] = expr_depth(e);
        uint32_t id = (uint32_t)++t->node_count;
        u32map_put(&t->expr_map, e, id);
    }
    return u32map_get(&t->expr_map, root_expr);
}

/* read a comma-separated list or @filepath (one constant name per line) into an array of member indices */
static uint32_t *parse_member_list(const char *spec, size_t *out_count) {
    uint32_t *res = NULL; size_t count = 0, cap = 0;
    if (spec[0] == '@') {
        FILE *f = fopen(spec + 1, "rb");
        if (!f) { fprintf(stderr, "leanexport: cannot read %s: %s\n", spec + 1, strerror(errno)); exit(1); }
        char *line = NULL; size_t lcap = 0; ssize_t len;
        while ((len = getline(&line, &lcap, f)) > 0) {
            while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r' || line[len - 1] == ' ' || line[len - 1] == '\t')) line[--len] = '\0';
            if (len == 0 || line[0] == '#') continue;
            int64_t m = member_by_text(line);
            if (m < 0) { fprintf(stderr, "leanexport: no declaration %s\n", line); exit(1); }
            push_u32(&res, &count, &cap, (uint32_t)m);
        }
        free(line);
        fclose(f);
    } else {
        char *copy = strdup(spec);
        for (char *tok = strtok(copy, ","); tok; tok = strtok(NULL, ",")) {
            if (!*tok) continue;
            int64_t m = member_by_text(tok);
            if (m < 0) { fprintf(stderr, "leanexport: no declaration %s\n", tok); exit(1); }
            push_u32(&res, &count, &cap, (uint32_t)m);
        }
        free(copy);
    }
    *out_count = count;
    return res;
}

typedef struct { uint32_t member; uint8_t with_value; } RootField;

typedef struct {
    size_t expr_total;
    int64_t quot_members[4];
    uint32_t quot_decls[4];
    int has_all_quots;
    uint32_t str_decls[5];
    int str_decl_count;
    uint8_t *excluded, *keep_proof, *reached, *as_axiom, *seen, *const_emitted;
    uint32_t *queue, *stack;
    size_t stack_cap;
    PostFrame *pstack;
    size_t pstack_cap;
} SliceCtx;

static void slice_ctx_init(SliceCtx *ctx) {
    memset(ctx, 0, sizeof *ctx);
    ctx->expr_total = t_exprs.size / 20;
    static const char *quot_names[4] = {"Quot", "Quot.mk", "Quot.lift", "Quot.ind"};
    ctx->has_all_quots = 1;
    for (int i = 0; i < 4; i++) {
        ctx->quot_members[i] = member_by_text(quot_names[i]);
        if (ctx->quot_members[i] < 0) ctx->has_all_quots = 0;
        else ctx->quot_decls[i] = g_members[ctx->quot_members[i]].decl;
    }
    static const char *str_const_names[5] = {"String.ofList", "List.cons", "List.nil", "Char.ofNat", "Char"};
    for (int i = 0; i < 5; i++) {
        int64_t m = member_by_text(str_const_names[i]);
        if (m >= 0) ctx->str_decls[ctx->str_decl_count++] = g_members[m].decl;
    }
    ctx->excluded = malloc(g_decl_count ? g_decl_count : 1);
    ctx->keep_proof = malloc(g_decl_count ? g_decl_count : 1);
    ctx->reached = malloc(g_decl_count ? g_decl_count : 1);
    ctx->as_axiom = malloc(g_decl_count ? g_decl_count : 1);
    ctx->seen = malloc(ctx->expr_total / 8 + 1);
    ctx->const_emitted = malloc(g_member_count ? g_member_count : 1);
    ctx->queue = malloc((g_decl_count ? g_decl_count : 1) * sizeof(uint32_t));
    ctx->stack_cap = 1 << 16;
    ctx->stack = malloc(ctx->stack_cap * sizeof(uint32_t));
    if (!ctx->excluded || !ctx->keep_proof || !ctx->reached || !ctx->as_axiom || !ctx->seen || !ctx->const_emitted || !ctx->queue || !ctx->stack)
        fail("out of memory");
}

static void slice_ctx_free(SliceCtx *ctx) {
    free(ctx->excluded); free(ctx->keep_proof); free(ctx->reached); free(ctx->as_axiom);
    free(ctx->seen); free(ctx->const_emitted); free(ctx->queue); free(ctx->stack); free(ctx->pstack);
}

static int slice_one(SliceCtx *ctx, const char *out_path, int axiomatize_all,
                     const char *proofs_for_spec, const char *exclude_spec, const char *roots_spec) {
    size_t expr_total = ctx->expr_total;
    int64_t *quot_members = ctx->quot_members;
    uint32_t *quot_decls = ctx->quot_decls;
    int has_all_quots = ctx->has_all_quots;
    uint32_t *str_decls = ctx->str_decls;
    int str_decl_count = ctx->str_decl_count;

    uint8_t *excluded = ctx->excluded;
    uint8_t *keep_proof = ctx->keep_proof;
    uint8_t *reached = ctx->reached;
    uint8_t *as_axiom = ctx->as_axiom;
    uint8_t *seen = ctx->seen;
    uint32_t *queue = ctx->queue;
    memset(excluded, 0, g_decl_count);
    memset(keep_proof, 0, g_decl_count);
    memset(reached, 0, g_decl_count);
    memset(as_axiom, 0, g_decl_count);
    memset(seen, 0, expr_total / 8 + 1);

    if (exclude_spec) {
        size_t n = 0; uint32_t *ms = parse_member_list(exclude_spec, &n);
        for (size_t i = 0; i < n; i++) {
            uint32_t d = g_members[ms[i]].decl;
            if (g_decl_list[d].kind == K_QUOT && has_all_quots) { for (int q = 0; q < 4; q++) excluded[quot_decls[q]] = 1; }
            else excluded[d] = 1;
        }
        free(ms);
    }
    if (proofs_for_spec) {
        size_t n = 0; uint32_t *ms = parse_member_list(proofs_for_spec, &n);
        for (size_t i = 0; i < n; i++) keep_proof[g_members[ms[i]].decl] = 1;
        free(ms);
    }

    size_t head = 0, tail = 0;
    size_t root_n = 0; uint32_t *root_ms = parse_member_list(roots_spec, &root_n);
    for (size_t i = 0; i < root_n; i++) {
        uint32_t d = g_members[root_ms[i]].decl;
        if (g_decl_list[d].kind == K_QUOT && has_all_quots) {
            for (int q = 0; q < 4; q++) if (!excluded[quot_decls[q]] && !reached[quot_decls[q]]) { reached[quot_decls[q]] = 1; queue[tail++] = quot_decls[q]; }
        } else if (!excluded[d] && !reached[d]) {
            reached[d] = 1; queue[tail++] = d;
        }
    }
    free(root_ms);

    /* one-pass BFS over reachable expressions */
    uint64_t backward_edges = 0;
    while (head < tail) {
        uint32_t d = queue[head++];
        Decl *decl = &g_decl_list[d];
        int walk_val = 0;
        if (decl->kind == K_THEOREM) {
            if (axiomatize_all || (proofs_for_spec && !keep_proof[d])) as_axiom[d] = 1;
            else walk_val = 1;
        } else if (decl->kind == K_DEFINITION || decl->kind == K_OPAQUE) {
            walk_val = 1;
        }
        size_t top = 0;
        for (uint32_t k = 0; k < decl->type_root_count; k++) {
            if (top == ctx->stack_cap) { ctx->stack_cap *= 2; ctx->stack = realloc(ctx->stack, ctx->stack_cap * sizeof(uint32_t)); }
            ctx->stack[top++] = g_type_roots[decl->first_type_root + k];
        }
        if (walk_val) {
            for (uint32_t k = 0; k < decl->val_root_count; k++) {
                if (top == ctx->stack_cap) { ctx->stack_cap *= 2; ctx->stack = realloc(ctx->stack, ctx->stack_cap * sizeof(uint32_t)); }
                ctx->stack[top++] = g_val_roots[decl->first_val_root + k];
            }
        }
        while (top) {
            uint32_t e = ctx->stack[--top];
            if (e >= expr_total) { fprintf(stderr, "leanexport: expression %u out of range\n", e); return 1; }
            if (seen[e >> 3] & (1u << (e & 7))) continue;
            seen[e >> 3] |= (uint8_t)(1u << (e & 7));
            uint32_t row[5], ch[3], nc = 0;
            expr_row(e, row);
            switch (row[0]) {
                case 2: {
                    int64_t m = member_of_name(row[1]);
                    if (m < 0) { char *n = name_string(row[1]); fprintf(stderr, "leanexport: %s is used but not declared\n", n); free(n); return 1; }
                    uint32_t target = g_members[m].decl;
                    if (target > d && !(decl->kind == K_QUOT && g_decl_list[target].kind == K_QUOT)) backward_edges++;
                    if (g_decl_list[target].kind == K_QUOT && has_all_quots) {
                        for (int q = 0; q < 4; q++) if (!excluded[quot_decls[q]] && !reached[quot_decls[q]]) { reached[quot_decls[q]] = 1; queue[tail++] = quot_decls[q]; }
                    } else if (!excluded[target] && !reached[target]) {
                        reached[target] = 1; queue[tail++] = target;
                    }
                    break;
                }
                case 8:
                    for (int i = 0; i < str_decl_count; i++) {
                        uint32_t target = str_decls[i];
                        if (target > d) backward_edges++;
                        if (!excluded[target] && !reached[target]) { reached[target] = 1; queue[tail++] = target; }
                    }
                    break;
                case 3: ch[nc++] = row[1]; ch[nc++] = row[2]; break;
                case 4: case 5: ch[nc++] = row[2]; ch[nc++] = row[3]; break;
                case 6: ch[nc++] = row[2]; ch[nc++] = row[3]; ch[nc++] = row[4]; break;
                case 9: ch[nc++] = row[3]; break;
                default: break;
            }
            for (uint32_t i = 0; i < nc; i++) {
                if (top == ctx->stack_cap) { ctx->stack_cap *= 2; ctx->stack = realloc(ctx->stack, ctx->stack_cap * sizeof(uint32_t)); }
                ctx->stack[top++] = ch[i];
            }
        }
    }
    if (backward_edges > 0) {
        fprintf(stderr, "leanexport: warning: %llu backward edges in export order\n", (unsigned long long)backward_edges);
    }

    /* Quot emits once at the last reached Quot* declaration */
    int64_t quot_emit_decl = -1;
    if (has_all_quots && reached[quot_decls[0]]) {
        uint32_t maxq = quot_decls[0];
        for (int q = 1; q < 4; q++) if (quot_decls[q] > maxq) maxq = quot_decls[q];
        quot_emit_decl = (int64_t)maxq;
    }

    /* collect Order, Constants members, Inductives, and exact RootFields matching Catenate[fieldNames /@ order] */
    uint32_t *order_names = NULL; size_t order_count = 0, order_cap = 0;
    uint32_t *const_members = NULL; size_t const_count = 0, const_cap = 0;
    uint32_t *ind_indices = NULL; size_t ind_out_count = 0, ind_out_cap = 0;
    RootField *root_fields = NULL; size_t rf_count = 0, rf_cap = 0;
    uint64_t axiomatized_count = 0, proved_count = 0;

    for (size_t d = 0; d < g_decl_count; d++) {
        if (!reached[d]) continue;
        Decl *decl = &g_decl_list[d];
        if (decl->kind == K_QUOT) {
            if ((int64_t)d != quot_emit_decl) continue;
            push_u32(&order_names, &order_count, &order_cap, g_members[quot_members[0]].name);
            for (int q = 0; q < 4; q++) {
                uint32_t qm = (uint32_t)quot_members[q];
                push_u32(&const_members, &const_count, &const_cap, qm);
                if (rf_count == rf_cap) { rf_cap = rf_cap ? 2 * rf_cap : 1 << 14; root_fields = realloc(root_fields, rf_cap * sizeof(RootField)); }
                root_fields[rf_count++] = (RootField){qm, 0};
            }
            continue;
        }
        if (decl->kind == K_INDUCTIVE) {
            IndType *it0 = &g_ind_types[decl->first_ind];
            uint32_t primary_name = g_ind_names[it0->first_all];
            push_u32(&order_names, &order_count, &order_cap, primary_name);
            for (uint32_t k = 0; k < decl->member_count; k++)
                push_u32(&const_members, &const_count, &const_cap, decl->first_member + k);
            for (uint32_t k = 0; k < decl->ind_count; k++)
                push_u32(&ind_indices, &ind_out_count, &ind_out_cap, (uint32_t)decl->first_ind + k);
            /* fieldNames order: block types (in all order), then blockConstructors, then blockRecursors */
            for (uint32_t k = 0; k < it0->all_count; k++) {
                int64_t m = member_of_name(g_ind_names[it0->first_all + k]);
                if (m < 0) fail("inductive block type missing");
                if (rf_count == rf_cap) { rf_cap = rf_cap ? 2 * rf_cap : 1 << 14; root_fields = realloc(root_fields, rf_cap * sizeof(RootField)); }
                root_fields[rf_count++] = (RootField){(uint32_t)m, 0};
            }
            for (uint32_t k = 0; k < it0->all_count; k++) {
                uint32_t tname = g_ind_names[it0->first_all + k];
                IndType *tv = NULL;
                for (uint32_t j = 0; j < decl->ind_count; j++)
                    if (g_members[g_ind_types[decl->first_ind + j].member].name == tname) { tv = &g_ind_types[decl->first_ind + j]; break; }
                if (!tv) fail("inductive type metadata missing");
                for (uint32_t c = 0; c < tv->ctor_count; c++) {
                    int64_t cm = member_of_name(g_ind_names[tv->first_ctor + c]);
                    if (cm < 0) fail("inductive constructor missing");
                    if (rf_count == rf_cap) { rf_cap = rf_cap ? 2 * rf_cap : 1 << 14; root_fields = realloc(root_fields, rf_cap * sizeof(RootField)); }
                    root_fields[rf_count++] = (RootField){(uint32_t)cm, 0};
                }
            }
            for (uint32_t k = 0; k < it0->all_count; k++) {
                char *tn = name_string(g_ind_names[it0->first_all + k]);
                size_t tlen = strlen(tn);
                char *rn = malloc(tlen + 16);
                snprintf(rn, tlen + 16, "%s.rec", tn);
                int64_t rm = member_by_text(rn);
                free(tn); free(rn);
                if (rm < 0) fail("inductive recursor missing");
                if (rf_count == rf_cap) { rf_cap = rf_cap ? 2 * rf_cap : 1 << 14; root_fields = realloc(root_fields, rf_cap * sizeof(RootField)); }
                root_fields[rf_count++] = (RootField){(uint32_t)rm, 0};
            }
            if (it0->num_nested > 0) {
                char *p0 = name_string(primary_name);
                size_t plen = strlen(p0);
                char *rn = malloc(plen + 32);
                for (uint32_t k = 1; k <= it0->num_nested; k++) {
                    snprintf(rn, plen + 32, "%s.rec_%u", p0, k);
                    int64_t rm = member_by_text(rn);
                    if (rm < 0) fail("nested inductive recursor missing");
                    if (rf_count == rf_cap) { rf_cap = rf_cap ? 2 * rf_cap : 1 << 14; root_fields = realloc(root_fields, rf_cap * sizeof(RootField)); }
                    root_fields[rf_count++] = (RootField){(uint32_t)rm, 0};
                }
                free(p0); free(rn);
            }
            continue;
        }
        uint32_t m = decl->first_member;
        push_u32(&order_names, &order_count, &order_cap, g_members[m].name);
        push_u32(&const_members, &const_count, &const_cap, m);
        uint8_t with_val = 0;
        if (decl->kind == K_THEOREM) {
            if (as_axiom[d]) axiomatized_count++;
            else { with_val = 1; proved_count++; }
        } else if (decl->kind == K_DEFINITION || decl->kind == K_OPAQUE) {
            with_val = 1;
        }
        if (rf_count == rf_cap) { rf_cap = rf_cap ? 2 * rf_cap : 1 << 14; root_fields = realloc(root_fields, rf_cap * sizeof(RootField)); }
        root_fields[rf_count++] = (RootField){m, with_val};
    }

    /* remap all expressions reachable from root_fields */
    SliceTable tbl;
    slice_table_init(&tbl);
    uint32_t *roots_packed = malloc((rf_count ? rf_count * 2 : 1) * sizeof(uint32_t));
    if (!roots_packed) fail("out of memory");
    for (size_t i = 0; i < rf_count; i++) {
        Member *m = &g_members[root_fields[i].member];
        uint32_t tn = slice_expr(&tbl, m->type_expr, &ctx->pstack, &ctx->pstack_cap);
        uint32_t vn = 0;
        if (root_fields[i].with_value && m->val_expr >= 0)
            vn = slice_expr(&tbl, (uint32_t)m->val_expr, &ctx->pstack, &ctx->pstack_cap);
        roots_packed[2 * i] = tn;
        roots_packed[2 * i + 1] = vn;
    }

    /* Also include any excluded declared member referenced in Table["Names"] inside "Constants"
       so the bridge's constantName/constantKind lookup (e.g. recursors) never needs a Lean handle. */
    uint8_t *const_emitted = ctx->const_emitted;
    memset(const_emitted, 0, g_member_count);
    for (size_t i = 0; i < const_count; i++) const_emitted[const_members[i]] = 1;
    for (size_t i = 0; i < tbl.name_count; i++) {
        int64_t m = member_of_name(tbl.names[i]);
        if (m >= 0 && excluded[g_members[m].decl] && !const_emitted[m]) {
            const_emitted[m] = 1;
            push_u32(&const_members, &const_count, &const_cap, (uint32_t)m);
        }
    }

    /* write WXF bundle */
    FILE *out = fopen(out_path, "wb");
    if (!out) { fprintf(stderr, "leanexport: cannot write %s: %s\n", out_path, strerror(errno)); return 1; }
    setvbuf(out, NULL, _IOFBF, 1 << 22);
    fwrite("8:", 1, 2, out);
    wxf_assoc_head(out, 4);

    /* "Order" */
    fputc('-', out); wxf_string(out, "Order");
    wxf_list_head(out, order_count);
    for (size_t i = 0; i < order_count; i++) {
        char *s = name_string(order_names[i]);
        wxf_string(out, s);
        free(s);
    }

    /* "Constants" */
    fputc('-', out); wxf_string(out, "Constants");
    wxf_assoc_head(out, const_count);
    for (size_t i = 0; i < const_count; i++) {
        Member *m = &g_members[const_members[i]];
        char *s = name_string(m->name);
        const char *kstr = (m->kind == K_THEOREM && as_axiom[m->decl]) ? "axiom" : bridge_kind_names[m->kind];
        fputc('-', out); wxf_string(out, s); free(s);
        wxf_list_head(out, 2);
        wxf_string(out, kstr);
        wxf_list_head(out, m->lparam_count);
        for (uint32_t j = 0; j < m->lparam_count; j++) {
            char *lp = name_string(g_lparams[m->first_lparam + j]);
            wxf_string(out, lp); free(lp);
        }
    }

    /* "Inductives" */
    fputc('-', out); wxf_string(out, "Inductives");
    wxf_assoc_head(out, ind_out_count);
    for (size_t i = 0; i < ind_out_count; i++) {
        IndType *it = &g_ind_types[ind_indices[i]];
        Decl *decl = &g_decl_list[g_members[it->member].decl];
        char *tn = name_string(g_members[it->member].name);
        fputc('-', out); wxf_string(out, tn); free(tn);
        wxf_list_head(out, 5);
        wxf_int(out, it->num_params);
        /* block */
        wxf_list_head(out, it->all_count);
        for (uint32_t k = 0; k < it->all_count; k++) {
            char *bn = name_string(g_ind_names[it->first_all + k]);
            wxf_string(out, bn); free(bn);
        }
        wxf_int(out, it->num_nested);
        /* blockConstructors: concat of tv->ctors for tv in it->all order */
        size_t total_bctors = 0;
        for (uint32_t k = 0; k < it->all_count; k++) {
            uint32_t bname = g_ind_names[it->first_all + k];
            for (uint32_t j = 0; j < decl->ind_count; j++)
                if (g_members[g_ind_types[decl->first_ind + j].member].name == bname) { total_bctors += g_ind_types[decl->first_ind + j].ctor_count; break; }
        }
        wxf_list_head(out, total_bctors);
        for (uint32_t k = 0; k < it->all_count; k++) {
            uint32_t bname = g_ind_names[it->first_all + k];
            for (uint32_t j = 0; j < decl->ind_count; j++) {
                IndType *tv = &g_ind_types[decl->first_ind + j];
                if (g_members[tv->member].name == bname) {
                    for (uint32_t c = 0; c < tv->ctor_count; c++) {
                        char *cn = name_string(g_ind_names[tv->first_ctor + c]);
                        wxf_string(out, cn); free(cn);
                    }
                    break;
                }
            }
        }
        /* own constructors */
        wxf_list_head(out, it->ctor_count);
        for (uint32_t c = 0; c < it->ctor_count; c++) {
            char *cn = name_string(g_ind_names[it->first_ctor + c]);
            wxf_string(out, cn); free(cn);
        }
    }

    /* "Table" */
    fputc('-', out); wxf_string(out, "Table");
    wxf_assoc_head(out, 8);
    fputc('-', out); wxf_string(out, "Nodes"); wxf_packed_i32_2d(out, tbl.nodes, tbl.node_count, 5);
    fputc('-', out); wxf_string(out, "Depths"); wxf_packed_i32_1d(out, tbl.depths, tbl.node_count);
    fputc('-', out); wxf_string(out, "Names");
    wxf_list_head(out, tbl.name_count);
    for (size_t i = 0; i < tbl.name_count; i++) { char *s = name_string(tbl.names[i]); wxf_string(out, s); free(s); }
    fputc('-', out); wxf_string(out, "Levels"); wxf_packed_i32_2d(out, tbl.levels, tbl.level_count, 3);
    fputc('-', out); wxf_string(out, "LevelLists");
    wxf_list_head(out, tbl.ll_count);
    for (size_t i = 0; i < tbl.ll_count; i++) {
        Span sp = tbl.ll_spans[i];
        wxf_list_head(out, sp.len);
        for (uint32_t j = 0; j < sp.len; j++) wxf_int(out, tbl.ll_items[sp.off + j]);
    }
    fputc('-', out); wxf_string(out, "Naturals");
    wxf_list_head(out, tbl.nat_count);
    for (size_t i = 0; i < tbl.nat_count; i++) {
        uint32_t n; const char *s = string_at(tbl.nats[i], &n);
        wxf_nat_digits(out, s, n);
    }
    fputc('-', out); wxf_string(out, "Strings");
    wxf_list_head(out, tbl.str_count);
    for (size_t i = 0; i < tbl.str_count; i++) {
        uint32_t n; const char *s = string_at(tbl.strs[i], &n);
        wxf_string_n(out, s, n);
    }
    fputc('-', out); wxf_string(out, "Roots"); wxf_packed_i32_2d(out, roots_packed, rf_count, 2);

    if (fclose(out) != 0) fail("a write failed");
    printf("slice: %s: %zu primaries, %zu constants (%llu proved, %llu axiomatized), %zu fields, %zu nodes, %zu names, %zu levels\n",
        out_path, order_count, const_count, (unsigned long long)proved_count, (unsigned long long)axiomatized_count,
        rf_count, tbl.node_count, tbl.name_count, tbl.level_count);
    fflush(stdout);

    slice_table_free(&tbl);
    free(order_names); free(const_members); free(ind_indices); free(root_fields); free(roots_packed);
    return 0;
}

static int parse_slice_args(int argc, char **argv, const char **out_path, int *axiomatize_all,
                            const char **proofs_for_spec, const char **exclude_spec, const char **roots_spec) {
    if (argc < 2) return 2;
    *out_path = argv[0];
    *axiomatize_all = 0;
    *proofs_for_spec = NULL;
    *exclude_spec = NULL;
    *roots_spec = NULL;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--axiomatize-theorems") == 0) *axiomatize_all = 1;
        else if (strcmp(argv[i], "--proofs-for") == 0 && i + 1 < argc) *proofs_for_spec = argv[++i];
        else if (strcmp(argv[i], "--exclude") == 0 && i + 1 < argc) *exclude_spec = argv[++i];
        else if (!*roots_spec) *roots_spec = argv[i];
        else { fprintf(stderr, "leanexport: unexpected argument %s\n", argv[i]); return 2; }
    }
    if (!*roots_spec) { fprintf(stderr, "leanexport: missing ROOTS\n"); return 2; }
    return 0;
}

static int slice_cmd(int argc, char **argv) {
    if (argc < 5) {
        fprintf(stderr, "usage: leanexport slice OUTDIR SLICE.wxf [--axiomatize-theorems] [--proofs-for LIST] [--exclude LIST] ROOTS\n");
        return 2;
    }
    const char *dir = argv[2];
    const char *out_path, *proofs_for_spec, *exclude_spec, *roots_spec;
    int axiomatize_all;
    if (parse_slice_args(argc - 3, argv + 3, &out_path, &axiomatize_all, &proofs_for_spec, &exclude_spec, &roots_spec) != 0) return 2;
    if (load_decls_and_names(dir, 1) != 0) return 1;
    SliceCtx ctx;
    slice_ctx_init(&ctx);
    int rc = slice_one(&ctx, out_path, axiomatize_all, proofs_for_spec, exclude_spec, roots_spec);
    slice_ctx_free(&ctx);
    return rc;
}

static int slice_batch_cmd(const char *dir, const char *manifest_path) {
    if (load_decls_and_names(dir, 1) != 0) return 1;
    FILE *mf = strcmp(manifest_path, "-") == 0 ? stdin : fopen(manifest_path, "rb");
    if (!mf) { fprintf(stderr, "leanexport: cannot read %s: %s\n", manifest_path, strerror(errno)); return 1; }
    SliceCtx ctx;
    slice_ctx_init(&ctx);

    char *line = NULL; size_t lcap = 0; ssize_t len;
    size_t shards = 0;
    int rc = 0;
    while ((len = getline(&line, &lcap, mf)) > 0) {
        while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) line[--len] = '\0';
        char *p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '\0' || *p == '#') continue;
        char *toks[32]; int ntok = 0;
        while (*p && ntok < 32) {
            toks[ntok++] = p;
            while (*p && *p != ' ' && *p != '\t') p++;
            if (*p) { *p++ = '\0'; while (*p == ' ' || *p == '\t') p++; }
        }
        const char *out_path, *proofs_for_spec, *exclude_spec, *roots_spec;
        int axiomatize_all;
        if (parse_slice_args(ntok, toks, &out_path, &axiomatize_all, &proofs_for_spec, &exclude_spec, &roots_spec) != 0) { rc = 2; break; }
        rc = slice_one(&ctx, out_path, axiomatize_all, proofs_for_spec, exclude_spec, roots_spec);
        if (rc != 0) break;
        shards++;
    }
    free(line);
    if (mf != stdin) fclose(mf);
    slice_ctx_free(&ctx);
    if (rc == 0) printf("slice-batch: %zu shards written\n", shards);
    return rc;
}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "convert") == 0) return convert(argv[2]);
    if ((argc == 5 || argc == 6) && strcmp(argv[1], "cone") == 0) return cone(argv[2], argv[3], argv[4], argc == 6 ? argv[5] : NULL);
    if ((argc == 3 || argc == 4) && strcmp(argv[1], "deps") == 0) return deps_cmd(argv[2], argc == 4 ? argv[3] : NULL);
    if (argc >= 5 && strcmp(argv[1], "slice") == 0) return slice_cmd(argc, argv);
    if (argc == 4 && strcmp(argv[1], "slice-batch") == 0) return slice_batch_cmd(argv[2], argv[3]);
    fprintf(stderr,
        "usage: leanexport convert OUTDIR < export.ndjson\n"
        "       leanexport cone OUTDIR CONE.tsv root,root,... [target,target,...]\n"
        "       leanexport deps OUTDIR [DEPS.bin]\n"
        "       leanexport slice OUTDIR SLICE.wxf [--axiomatize-theorems] [--proofs-for LIST] [--exclude LIST] ROOTS\n"
        "       leanexport slice-batch OUTDIR MANIFEST\n");
    return 2;
}
