import os

#include <fcntl.h>
#include <unistd.h>

fn C.readlink(pathname &char, buf &char, bufsiz usize) int

pub fn do_readlink(path string) !string {
	mut result := [os.max_path_len]u8{}
	size := C.readlink(&char(path.str), &char(&result), os.max_path_len)
	if size < 0 {
		return os.error_posix()
	}
	result[size] = 0
	s := unsafe { tos_clone(&result[0]) }
	return s
}
