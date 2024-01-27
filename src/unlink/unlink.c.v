#include <sys/stat.h> // #include <signal.h>
#include <errno.h>
#include <unistd.h>

$if freebsd || openbsd {
	#include <sys/sysctl.h>
}

fn C.unlink(&char) int

// TODO: See if this can be imported from somewhere
pub enum Errno {
	enoerror = 0x00000000
	e2big    = 0x00000007
	eacces   = 0x0000000d
	eagain   = 0x0000000b
	ebadf    = 0x00000009
	ebusy    = 0x00000010
	echild   = 0x0000000a
	edom     = 0x00000021
	eexist   = 0x00000011
	efault   = 0x0000000e
	efbig    = 0x0000001b
	eintr    = 0x00000004
	einval   = 0x00000016
	eio      = 0x00000005
	eisdir   = 0x00000015
	emfile   = 0x00000018
	emlink   = 0x0000001f
	enfile   = 0x00000017
	enodev   = 0x00000013
	enoent   = 0x00000002
	enoexec  = 0x00000008
	enomem   = 0x0000000c
	enospc   = 0x0000001c
	enotblk  = 0x0000000f
	enotdir  = 0x00000014
	enotty   = 0x00000019
	enxio    = 0x00000006
	eperm    = 0x00000001
	epipe    = 0x00000020
	erange   = 0x00000022
	erofs    = 0x0000001e
	espipe   = 0x0000001d
	esrch    = 0x00000003
	etxtbsy  = 0x0000001a
	exdev    = 0x00000012
}

fn unlink(settings Settings) {
	err := C.unlink(&char(settings.target.str))
	if err != 0 {
		unsafe {
			e := Errno(C.errno)
			match e {
				.enoent {
					fail("cannot unlink '${settings.target}': No such file or directory")
				}
				.eisdir {
					fail("cannot unlink '${settings.target}': Is a directory")
				}
				else {
					fail("cannot unlink '${settings.target}': error ${e}")
				}
			}
		}
	}
}
