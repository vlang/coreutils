module pwd

import os

// This is the kernel limitation of how many groups a user can be in
const max_group_count = 65536

#include <pwd.h>
#include <grp.h>
#include <unistd.h>

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
fn C.getgroups(int, &int) int

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

pub fn get_groups_up_to(limit int) !(int, []int) {
	mut groups := []int{len: 256}
	unsafe {
		num_groups := C.getgroups(limit, &groups[0])
		if num_groups < 0 {
			return os.error_posix()
		}
		return num_groups, groups
	}
}

pub fn get_groups() ![]int {
	// Most users will not be in more than 256 groups, so why
	// allocate more RAM unless we absolutely need to?
	mut num_groups, mut groups := get_groups_up_to(256)!
	if num_groups == 255 {
		// Maybe we have a user in more than 256 groups after all,
		// now let's check up to the kernel limit
		num_groups, groups = get_groups_up_to(max_group_count)!
	}
	return groups[0..num_groups]
}

pub fn whoami() !string {
	uid := os.geteuid()
	if uid == -1 {
		return error('no user name')
	}
	return get_name_for_uid(uid)
}
