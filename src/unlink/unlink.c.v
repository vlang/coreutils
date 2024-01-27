import os

#include <sys/stat.h> // #include <signal.h>
#include <errno.h>
#include <unistd.h>

$if freebsd || openbsd {
	#include <sys/sysctl.h>
}

fn C.unlink(&char) int

fn unlink(settings Settings) {
	err := C.unlink(&char(settings.target.str))
	if err != 0 {
		posix_error := os.posix_get_error_msg(C.errno)
		fail("cannot unlink '${settings.target}': ${posix_error}")
	}
}
