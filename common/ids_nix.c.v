module common

#include <grp.h>
#include <pwd.h>

import os

fn C.getgrnam(name &char) &C.group
fn C.getpwnam(name &char) &C.passwd

pub struct C.group {
mut:
	gr_name   &char
	gr_passwd &char
	gr_gid    u32
	gr_mem    &&char
}

pub struct C.passwd {
mut:
	pw_name   &char
	pw_passwd &char
	pw_uid    u32
	pw_gid    u32
	pw_gecos  &char
	pw_dir    &char
	pw_shell  &char
}

// leave_alone is the "do not change this half" marker chown(2) expects. It is
// spelled -1, which as a u32 is the maximum value, and chown and chgrp both use
// it when only one of owner/group was named.
pub const leave_alone = u32(4294967295)

// change_owner sets the owner and group of one path. os.chown is the stdlib
// binding and returns void, so success is 0 and any failure is -1.
pub fn change_owner(path string, owner u32, group u32) int {
	os.chown(path, int(owner), int(group)) or { return -1 }
	return 0
}

// group_id resolves a group name to its id, or none when there is no such
// group. A name that is all digits is taken as an id directly, which is what
// GNU's "owner:group" parser does.
pub fn group_id(name string) ?u32 {
	if name == '' {
		return none
	}
	if is_all_digits(name) {
		return u32(name.int())
	}
	g := C.getgrnam(&char(name.str))
	if isnil(g) {
		return none
	}
	return g.gr_gid
}

// user_id resolves a user name to its id, or none when there is no such user.
pub fn user_id(name string) ?u32 {
	if name == '' {
		return none
	}
	if is_all_digits(name) {
		return u32(name.int())
	}
	p := C.getpwnam(&char(name.str))
	if isnil(p) {
		return none
	}
	return p.pw_uid
}

fn is_all_digits(s string) bool {
	if s == '' {
		return false
	}
	for c in s.bytes() {
		if c < `0` || c > `9` {
			return false
		}
	}
	return true
}

// user_name is the login name for an id, or the id itself when there is no
// matching account.
pub fn user_name(uid u32) string {
	return uid.str()
}

pub fn group_name(gid u32) string {
	return gid.str()
}
