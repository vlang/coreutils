module pwd

import os

#include <pwd.h>
#include <grp.h>

struct C.passwd {
	pw_name   &char
	pw_passwd &char
	pw_uid    u32
	pw_gid    u32
	pw_gecos  &char
	pw_dir    &char
	pw_shell  &char
}

fn C.getpwuid(int) &C.passwd
fn C.getgrgid(int) &C.passwd

pub fn get_name_for_gid(gid int) !string {
	pwd := C.getgrgid(gid)
	unsafe {
		if isnil(pwd) {
			// Call succeeded but user not found
			if C.errno == 0 {
				return ''
			}
			return os.error_posix()
		}
		return cstring_to_vstring(pwd.pw_name)
	}
}

pub fn get_name_for_uid(uid int) !string {
	pwd := C.getpwuid(uid)
	unsafe {
		if isnil(pwd) {
			// Call succeeded but user not found
			if C.errno == 0 {
				return ''
			}
			return os.error_posix()
		}
		return cstring_to_vstring(pwd.pw_name)
	}
}

pub fn whoami() !string {
	uid := os.geteuid()
	if uid == -1 {
		return error('no user name')
	}
	return get_name_for_uid(uid)
}
