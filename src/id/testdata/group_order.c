#include <errno.h>
#include <grp.h>
#include <sys/types.h>
#include <unistd.h>

/* Deliberately distinct process and account-database group orders. */
int getgroups(int size, gid_t *groups) {
    if (size == 0) return 3;
    if (size < 3) {
        errno = EINVAL;
        return -1;
    }
    gid_t primary = getegid();
    groups[0] = primary ^ 8;
    groups[1] = primary ^ 2;
    groups[2] = primary ^ 4;
    return 3;
}

int getgrouplist(const char *user, gid_t primary, gid_t *groups, int *count) {
    (void)user;
    if (*count < 4) {
        *count = 4;
        return -1;
    }
    groups[0] = primary;
    groups[1] = primary ^ 4;
    groups[2] = primary ^ 8;
    groups[3] = primary ^ 2;
    *count = 4;
    return 4;
}
