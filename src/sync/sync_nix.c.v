#include <unistd.h>

fn C.fsync(int) int
fn C.fdatasync(int) int
fn C.syncfs(int) int

fn do_sync(fd int) ! {
	res := C.syncfs(1)
	if res != 0 {
		error_with_code('syncfs failed', C.errno)
	}
}

fn do_fsync(fd int) ! {
	res := C.fsync(fd)
	if res != 0 {
		error_with_code('fsync failed', C.errno)
	}
}

fn do_fdatasync(fd int) ! {
	res := C.fdatasync(fd)
	if res != 0 {
		error_with_code('fdatasync failed', C.errno)
	}
}
