import os

#include <pwd.h>

struct C.passwd {
	pw_name &char
}

fn C.getpwuid(uid int) &C.passwd

fn whoami() !string {
	uid := os.geteuid()
	if uid == -1 {
		return error('no user name')
	}
	pwd := C.getpwuid(uid)
	return unsafe { cstring_to_vstring(pwd.pw_name) }
}
