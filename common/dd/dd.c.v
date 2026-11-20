module dd

#include <unistd.h>

fn C.write(fd i64, buf voidptr, count u64) i64

// write_fds is the wrapper the pure .v file calls. V no longer permits a C call
// directly in a .v file, so the declaration and the call have to sit on opposite
// sides of the .c.v boundary.
pub fn write_fds(fd i64, buf voidptr, count u64) i64 {
	return C.write(fd, buf, count)
}
