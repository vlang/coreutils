#include <sys/stat.h>
#include <sys/types.h>

fn C.mknod(path &char, mode u32, dev u64) int
fn C.umask(mode u32) u32

// mknod_mode builds the mode_t a file type character implies. `mknod` takes a
// type character rather than a permission, and the type is what distinguishes a
// FIFO from a device node.
pub fn make_node(path string, kind u8, mode u32, dev u64) int {
	return C.mknod(&char(path.str), mode, dev)
}

// read_umask returns the process umask without changing it.
pub fn read_umask() u32 {
	u := C.umask(0)
	C.umask(u)
	return u
}
