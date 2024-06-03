module main

#include <sys/time.h>

fn C.lutimes(&char, voidptr) int

fn lutime(path string, acctime int, modtime int) ! {
	times := [C.timeval{u64(acctime), u64(0)}, C.timeval{u64(modtime), u64(0)}]!
	if C.lutimes(&char(path.str), voidptr(&times[0])) != 0 {
		return error('lutime failed (${C.errno})')
	}
}
