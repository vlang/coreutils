#include <sys/stat.h>
#include <sys/types.h>

fn C.mknod(path &char, mode u32, dev u64) int

// mknod_mode builds the mode_t a file type character implies. `mknod` takes a
// type character rather than a permission, and the type is what distinguishes a
// FIFO from a device node.
pub fn make_node(path string, kind u8, mode u32, dev u64) int {
	return C.mknod(&char(path.str), mode, dev)
}

// device_number packs a major/minor pair the way makedev does. Device nodes are
// the only kind that needs it.
pub fn device_number(major int, minor int) u64 {
	return (u64(major) << 8) | u64(minor)
}
