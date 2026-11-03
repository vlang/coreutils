#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

static int queries;

static int fixture_is(const char *name) {
    const char *value = getenv("V_ID_GROUP_FIXTURE");
    return value != NULL && strcmp(value, name) == 0;
}

gid_t getgid(void) {
    return fixture_is("same") ? 55 : 0;
}

gid_t getegid(void) {
    return 55;
}

/* Override only this executable's group queries, without changing credentials. */
int getgroups(int size, gid_t *groups) {
    if (fixture_is("query_error")) {
        errno = EIO;
        return -1;
    }
    int count = fixture_is("many") || fixture_is("grow") ? 20 : 2;
    if (fixture_is("empty")) count = 0;
    if (fixture_is("primary")) count = 4;
    if (size == 0) {
        queries++;
        if (fixture_is("grow") && queries == 1) return 3;
        if (fixture_is("shrink")) return 20;
        return count;
    }
    if (fixture_is("read_error")) {
        errno = EIO;
        return -1;
    }
    if (fixture_is("busy") || size < count) {
        errno = EINVAL;
        return -1;
    }
    if (fixture_is("primary")) {
        groups[0] = 55;
        groups[1] = 22;
        groups[2] = 0;
        groups[3] = 33;
    } else if (count > 2) {
        for (int i = 0; i < count; i++) groups[i] = 100 + i;
    } else if (count == 2) {
        groups[0] = 22;
        groups[1] = 33;
    }
    return count;
}
