import os

#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
// The kernel uapi definitions of statx()/STATX_* live here. Do not use
// <bits/statx.h> for that: it is a glibc internal header, so it is missing on
// musl based distributions (see issue #145).
#include <linux/stat.h>

// vlib/builtin/cfns.c.v already declares a private `fn C.statvfs`, so a
// `fn C.statvfs` here resolves to that one and fails to compile. Give the libc
// call a distinct V-level name instead.
#define vcu_statvfs statvfs

// Mirror the kernel's `struct statx` exactly. Passing a V struct through a
// voidptr and hoping for the best truncates the kernel's 224 byte write to the
// size of the V view, which corrupts memory.
struct C.statx_timestamp {
	tv_sec   i64
	tv_nsec  u32
	reserved i32
}

// Ref: https://www.man7.org/linux/man-pages/man2/statx.2.html
struct C.statx {
	stx_mask             u32
	stx_blksize          u32
	stx_attributes       u64
	stx_nlink            u32
	stx_uid              u32
	stx_gid              u32
	stx_mode             u16
	__spare0             [1]u16
	stx_ino              u64
	stx_size             u64
	stx_blocks           u64
	stx_attributes_mask  u64
	stx_atime            C.statx_timestamp
	stx_btime            C.statx_timestamp
	stx_ctime            C.statx_timestamp
	stx_mtime            C.statx_timestamp
	stx_rdev_major       u32
	stx_rdev_minor       u32
	stx_dev_major        u32
	stx_dev_minor        u32
	stx_mnt_id           u64
	stx_dio_mem_align    u32
	stx_dio_offset_align u32
	__spare3             [12]u32
}

fn C.statx(int, &char, int, u32, &C.statx) int
fn C.vcu_statvfs(&char, voidptr) int
fn C.readlink(pathname &char, buf &char, bufsiz usize) int

const c_at_statx_sync_as_stat = 0x0000 // C.AT_STATX_SYNC_AS_STAT from fcntl.h
const c_at_statx_force_sync = 0x2000 // C.AT_STATX_FORCE_SYNC from fcntl.h
const c_at_statx_dont_sync = 0x4000 // C.AT_STATX_DONT_SYNC from fcntl.h
const c_at_symlink_nofollow = 0x0100 // C.AT_SYMLINK_NOFOLLOW from fcntl.h
const c_chmod_bits = C.S_ISUID | C.S_ISGID | C.S_ISVTX | C.S_IRWXU | C.S_IRWXG | C.S_IRWXO

fn statx(path string, dereference bool, cache_mode CacheMode) !Statx {
	mut c := C.statx{}
	unsafe {
		symlink_flag := if dereference { 0 } else { c_at_symlink_nofollow }
		sync_flag := match cache_mode {
			._default { c_at_statx_sync_as_stat }
			.always { c_at_statx_dont_sync }
			.never { c_at_statx_force_sync }
		}

		res := C.statx(0, os.abs_path(path).str, sync_flag | symlink_flag,
			C.STATX_BASIC_STATS | C.STATX_BTIME, &c)
		if res != 0 {
			return os.error_posix()
		}
	}
	return Statx{
		stx_mask:             c.stx_mask
		stx_blksize:          c.stx_blksize
		stx_attributes:       c.stx_attributes
		stx_nlink:            c.stx_nlink
		stx_uid:              c.stx_uid
		stx_gid:              c.stx_gid
		stx_mode:             c.stx_mode
		stx_ino:              c.stx_ino
		stx_size:             c.stx_size
		stx_blocks:           c.stx_blocks
		stx_attributes_mask:  c.stx_attributes_mask
		stx_atime:            to_timestamp(c.stx_atime)
		stx_btime:            to_timestamp(c.stx_btime)
		stx_ctime:            to_timestamp(c.stx_ctime)
		stx_mtime:            to_timestamp(c.stx_mtime)
		stx_rdev_major:       c.stx_rdev_major
		stx_rdev_minor:       c.stx_rdev_minor
		stx_dev_major:        c.stx_dev_major
		stx_dev_minor:        c.stx_dev_minor
		stx_mnt_id:           c.stx_mnt_id
		stx_dio_mem_align:    c.stx_dio_mem_align
		stx_dio_offset_align: c.stx_dio_offset_align
	}
}

fn to_timestamp(ts C.statx_timestamp) StatxTimestamp {
	return StatxTimestamp{
		tv_sec:  ts.tv_sec
		tv_nsec: ts.tv_nsec
	}
}

// statvfs() passes the V Statvfs struct through a voidptr, so that struct has
// to match the kernel's `struct statvfs` exactly, trailing spare included.
fn statvfs(path string) !Statvfs {
	mut s := Statvfs{}
	unsafe {
		res := C.vcu_statvfs(os.abs_path(path).str, voidptr(&s))
		if res != 0 {
			return os.error_posix()
		}
	}
	return s
}

pub fn readlink(path string) !string {
	mut result := [os.max_path_len]u8{}
	size := C.readlink(&char(path.str), &char(&result), os.max_path_len)
	if size < 0 {
		return os.error_posix()
	}
	result[size] = 0
	s := unsafe { tos_clone(&result[0]) }
	return s
}

pub fn get_filetype(mode u16) FileType {
	match mode & u32(C.S_IFMT) {
		u32(C.S_IFREG) {
			return .regular
		}
		u32(C.S_IFDIR) {
			return .directory
		}
		u32(C.S_IFCHR) {
			return .character_device
		}
		u32(C.S_IFBLK) {
			return .block_device
		}
		u32(C.S_IFIFO) {
			return .fifo
		}
		u32(C.S_IFLNK) {
			return .symbolic_link
		}
		u32(C.S_IFSOCK) {
			return .socket
		}
		// TODO: Special files types
		// u32(C.S_ISCTG) {
		// 	return .contiguous_data
		// }
		// u32(C.S_ISDOOR) {
		// 	return .door
		// }
		// u32(C.S_ISMPB){
		// 	return .multiplex_file
		// }
		// u32(C.S_ISMPC){
		// 	return .multiplex_file
		// }
		// u32(C.S_ISMPX) {
		// 	return .multiplex_file
		// }
		// u32(C.S_ISNWK) {
		// 	return .network_file
		// }
		// u32(C.S_ISPORT) {
		// 	return .port
		// }
		// u32(C.S_ISWHT) {
		// 	return .whiteout
		// }
		else {
			return .unknown
		}
	}
}

pub fn get_mode2(mode u16) FileMode {
	return FileMode{
		typ:    get_filetype(mode)
		owner:  FilePermission{
			read:    (mode & u32(C.S_IRUSR)) != 0
			write:   (mode & u32(C.S_IWUSR)) != 0
			execute: (mode & u32(C.S_IXUSR)) != 0
			special: (mode & u32(C.S_ISUID)) != 0
		}
		group:  FilePermission{
			read:    (mode & u32(C.S_IRGRP)) != 0
			write:   (mode & u32(C.S_IWGRP)) != 0
			execute: (mode & u32(C.S_IXGRP)) != 0
			special: (mode & u32(C.S_ISGID)) != 0
		}
		others: FilePermission{
			read:    (mode & u32(C.S_IROTH)) != 0
			write:   (mode & u32(C.S_IWOTH)) != 0
			execute: (mode & u32(C.S_IXOTH)) != 0
			special: (mode & u32(C.S_ISVTX)) != 0
		}
	}
}
