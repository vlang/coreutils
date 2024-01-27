import os

#include <errno.h>
$if !windows {
	#include <unistd.h>
}

fn C.unlink(&char) int

fn unlink(settings Settings) {
	$if !windows {
		err := C.unlink(&char(settings.target.str))
		if err != 0 {
			posix_error := os.posix_get_error_msg(C.errno)
			fail("cannot unlink '${settings.target}': ${posix_error}")
		}
	} $else {
		os.rm(settings.target) or { panic(err) }
	}
}
