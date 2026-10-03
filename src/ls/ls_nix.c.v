import os

#include <pwd.h>
#include <grp.h>
#include <unistd.h>

struct Passwd {
	pw_name  &char
	pw_uid   usize
	pw_gid   usize
	pw_dir   &char
	pw_shell &char
}

struct Group {
	gr_name &char
	gr_gid  usize
	gr_mem  &&char
}

fn C.getpwuid(uid usize) &Passwd
fn C.getgrgid(uid usize) &Group

// V's os.Stat has no st_blocks, and GNU's `total` line is the sum of those in
// 1K units, so the port cannot get the number any other way. vlib/os has the
// field in its own C.stat but drops it when it builds the platform-agnostic
// Stat, and it is not reachable as os.C.stat. Declaring the same struct here
// works because the field list is identical to the one vlib/os declares; a
// different name or layout breaks vlib's own call to C.lstat, which is the
// error this replaces. st_blocks was checked against `stat -c %b` rather than
// assumed, since the layout above is reproduced here.
struct C.stat {
	st_dev     u64
	st_ino     u64
	st_nlink   u64
	st_mode    u32
	st_uid     u32
	st_gid     u32
	st_rdev    u64
	st_size    u64
	st_blksize u64
	st_blocks  u64
	st_atime   i64
	st_mtime   i64
	st_ctime   i64
}

fn C.lstat(path &char, buf &C.stat) int

// allocated_size returns the space the entry occupies on disk, which is not
// what GNU's -h prints: a 3000 byte file on a 4K filesystem is shown as 3.0K,
// and a 200000 byte one as 196K. st_blocks is counted in 512 byte units.
fn allocated_size(path string) u64 {
	mut buf := C.stat{}
	unsafe {
		if C.lstat(path.str, &buf) != 0 {
			return 0
		}
	}
	return buf.st_blocks * 512
}

fn get_owner_name(uid usize) string {
	pwd := C.getpwuid(uid)
	unsafe {
		if isnil(pwd) {
			// Call succeeded but user not found
			if C.errno == 0 {
				return ''
			}
			return os.error_posix().msg()
		}
		return cstring_to_vstring(pwd.pw_name)
	}
}

fn get_group_name(uid usize) string {
	grp := C.getgrgid(uid)
	unsafe {
		if isnil(grp) {
			// Call succeeded but user not found
			if C.errno == 0 {
				return ''
			}
			return os.error_posix().msg()
		}
		return cstring_to_vstring(grp.gr_name)
	}
}

fn read_link(file string) string {
	buf_size := 2048
	buf := '\0'.repeat(buf_size)
	len := C.readlink(file.str, buf.str, usize(buf_size))
	if len == -1 {
		return os.error_posix().msg()
	}
	return buf.substr(0, len)
}
