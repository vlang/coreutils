#include "unistd.h"

fn C.dup2(oldfd int, newfd int) int

// dup2_fds is the wrapper the pure .v file calls. V no longer permits a C call
// directly in a .v file, so the declaration and the call have to sit on opposite
// sides of the .c.v boundary.
pub fn dup2_fds(oldfd int, newfd int) int {
	return C.dup2(oldfd, newfd)
}
