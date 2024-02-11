import os

#include <unistd.h>
#include <errno.h>

const c_stdin = C.STDIN_FILENO

fn C.isatty(int) int
fn C.ttyname(int) voidptr

pub fn isatty(fd int) !bool {
	res := C.isatty(fd)
	if res == 1 {
		return true
	}
	return os.error_posix()
}

pub fn ttyname(fd int) !string {
	unsafe {
		name_ptr := C.ttyname(fd)
		if name_ptr == nil || C.errno != 0 {
			return os.error_posix()
		}
		return cstring_to_vstring(name_ptr)
	}
}
