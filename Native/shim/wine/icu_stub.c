/*
 * icu_stub.c -- A stand-in for Windows' icu.dll, which Wine does not have, so that Lean's runtime loads under
 * Wine: the nine functions libInit_shared.dll imports, each failing with U_UNSUPPORTED_ERROR. For
 * test_windows_shim.sh only; it never ships.
 */

#include <stdint.h>

typedef int32_t UErrorCode;
typedef uint16_t UChar;
typedef double UDate;
typedef int8_t UBool;

#define U_UNSUPPORTED_ERROR 16

static void fail(UErrorCode *status) {
    if (status) {
        *status = U_UNSUPPORTED_ERROR;
    }
}

__declspec(dllexport) UChar *u_strFromUTF8(UChar *dest, int32_t capacity, int32_t *length, const char *src, int32_t srcLength, UErrorCode *status) {
    fail(status);
    return 0;
}

__declspec(dllexport) char *u_strToUTF8(char *dest, int32_t capacity, int32_t *length, const UChar *src, int32_t srcLength, UErrorCode *status) {
    fail(status);
    return 0;
}

__declspec(dllexport) void ucal_close(void *calendar) {
}

__declspec(dllexport) int32_t ucal_get(const void *calendar, int field, UErrorCode *status) {
    fail(status);
    return 0;
}

__declspec(dllexport) int32_t ucal_getTimeZoneDisplayName(const void *calendar, int type, const char *locale, UChar *result, int32_t length, UErrorCode *status) {
    fail(status);
    return 0;
}

__declspec(dllexport) int32_t ucal_getTimeZoneID(const void *calendar, UChar *result, int32_t length, UErrorCode *status) {
    fail(status);
    return 0;
}

__declspec(dllexport) UBool ucal_getTimeZoneTransitionDate(const void *calendar, int type, UDate *transition, UErrorCode *status) {
    fail(status);
    return 0;
}

__declspec(dllexport) void *ucal_open(const UChar *zone, int32_t length, const char *locale, int type, UErrorCode *status) {
    fail(status);
    return 0;
}

__declspec(dllexport) void ucal_setMillis(void *calendar, UDate time, UErrorCode *status) {
    fail(status);
}
