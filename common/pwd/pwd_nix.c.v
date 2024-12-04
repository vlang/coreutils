module pwd

import os

// There is no magic to 16, we just have to start with some buffer
// and this should cover how many groups a user is in for many typical systems.
const init_group_buf_size = 16
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
fn C.getpwnam(&char) &C.passwd
fn C.getgroups(int, &int) int
fn C.getgrouplist(&char, int, &int, &int) int

pub fn get_uid_for_name(username string) !int {
	r := C.getpwnam(username.str)
	if isnil(r) {
		return os.error_posix()
	}
	return int(r.pw_uid)
}

pub fn get_userinfo_for_name(username string) !UserInfo {
	r := C.getpwnam(username.str)
	if isnil(r) {
		return os.error_posix()
	}
	unsafe {
		return UserInfo{
			username: cstring_to_vstring(r.pw_name)
			uid:      int(r.pw_uid)
			gid:      int(r.pw_gid)
		}
	}
}

pub fn get_name_for_gid(gid int) !string {
	r := C.getgrgid(gid)
	unsafe {
		if isnil(r) {
			// Call succeeded but group not found
			if C.errno == 0 {
				return ''
			}
			return os.error_posix()
		}
		return cstring_to_vstring(r.pw_name)
	}
}

pub fn get_name_for_uid(uid int) !string {
	r := C.getpwuid(uid)
	unsafe {
		if isnil(r) {
			// Call succeeded but user not found
			if C.errno == 0 {
				return ''
			}
			return os.error_posix()
		}
		return cstring_to_vstring(r.pw_name)
	}
}

pub fn get_groups(username string) ![]int {
	user := get_userinfo_for_name(username)!
	unsafe {
		mut count := init_group_buf_size
		mut groups := []int{len: count}
		mut res := C.getgrouplist(username.str, user.gid, &groups[0], &count)
		// If the buffer was not big enough, count will be updated with the
		// number we need.
		if res == -1 {
			groups = []int{len: count}
			res = C.getgrouplist(username.str, user.gid, &groups[0], &count)
		}
		return groups[0..count]
	}
}

fn get_effective_groups_up_to(limit int) !(int, []int) {
	mut groups := []int{len: init_group_buf_size}
	unsafe {
		num_groups := C.getgroups(limit, &groups[0])
		if num_groups < 0 {
			return os.error_posix()
		}
		return num_groups, groups
	}
}

pub fn get_effective_groups() ![]int {
	mut num_groups, mut groups := get_effective_groups_up_to(init_group_buf_size)!
	if num_groups == init_group_buf_size - 1 {
		num_groups, groups = get_effective_groups_up_to(max_group_count)!
	}
	egid := os.getegid()
	idx := groups.index(egid)
	// The egid should be first in the array
	match idx {
		-1 {
			// Add it if it's not already there
			groups.prepend(egid)
			num_groups++
		}
		0 {
			// Nothing to do, that's exactly where we want the egid
		}
		else {
			// Move it to first place
			groups.delete(idx)
			groups.prepend(egid)
		}
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
