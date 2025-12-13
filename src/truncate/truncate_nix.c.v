#include <sys/stat.h>
#include <errno.h>

struct C.stat {
	st_dev     u64 // 8
	st_ino     u64 // 8
	st_nlink   u64 // 8
	st_mode    u32 // 4
	st_uid     u32 // 4
	st_gid     u32 // 4
	st_rdev    u64 // 8
	st_size    u64 // 8
	st_blksize u64 // 8
	st_blocks  u64 // 8
	st_atime   i64 // 8
	st_mtime   i64 // 8
	st_ctime   i64 // 8
}

// get_block_size for the --io-blocks option
pub fn get_block_size(path string) !u64 {
	mut s := C.stat{}
	unsafe {
		res := C.stat(&char(path.str), &s)
		if res != 0 {
			return error_with_code("unable to determine blocksize for '${path}'", C.errno)
		}
		return s.st_blksize
	}
}
