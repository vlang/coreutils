import os

#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <bits/statx.h>

// Ref: https://www.man7.org/linux/man-pages/man2/statx.2.html
fn C.statx(int, &char, int, u32, voidptr) int
fn C.statvfs(&char, voidptr) int
fn C.readlink(pathname &char, buf &char, bufsiz usize) int

const c_at_statx_sync_as_stat = 0x0000 // C.AT_STATX_SYNC_AS_STAT from fcntl.h
const c_at_statx_force_sync = 0x2000 // C.AT_STATX_FORCE_SYNC from fcntl.h
const c_at_statx_dont_sync = 0x4000 // C.AT_STATX_DONT_SYNC from fcntl.h
const c_at_symlink_nofollow = 0x0100 // C.AT_SYMLINK_NOFOLLOW from fcntl.h
const c_chmod_bits = C.S_ISUID | C.S_ISGID | C.S_ISVTX | C.S_IRWXU | C.S_IRWXG | C.S_IRWXO

fn statx(path string, dereference bool, cache_mode CacheMode) !Statx {
	mut s := Statx{}
	ptr := voidptr(&s)
	unsafe {
		symlink_flag := if dereference { 0 } else { c_at_symlink_nofollow }
		sync_flag := match cache_mode {
			._default { c_at_statx_sync_as_stat }
			.always { c_at_statx_dont_sync }
			.never { c_at_statx_force_sync }
		}
		res := C.statx(0, os.abs_path(path).str, sync_flag | symlink_flag, C.STATX_BASIC_STATS | C.STATX_BTIME,
			ptr)
		if res != 0 {
			return os.error_posix()
		}
	}
	return s
}

fn statvfs(path string) !Statvfs {
	mut s := Statvfs{}
	ptr := voidptr(&s)
	unsafe {
		res := C.statvfs(os.abs_path(path).str, ptr)
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
