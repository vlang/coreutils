import os

#include <sys/stat.h>
#include <errno.h>
#include <windows.h>

fn C.GetLastError() u32
fn C.GetDiskFreeSpaceA(voidptr, &u32, &u32, &u32, &u32) u32

// get_block_size for the --io-blocks option requires using GetDiskFreeSpaceA
// in the Windows API
pub fn get_block_size(path string) !u64 {
	dir := os.dir(path)
	unsafe {
		mut sectors_per_cluster := u32(0)
		mut bytes_per_sector := u32(0)
		mut number_of_free_clusters := u32(0)
		mut total_number_of_clusters := u32(0)
		res := C.GetDiskFreeSpaceA(&char(dir.str), voidptr(&sectors_per_cluster), voidptr(&bytes_per_sector),
			voidptr(&number_of_free_clusters), voidptr(&total_number_of_clusters))
		if res != 0 {
			return sectors_per_cluster * bytes_per_sector
		} else {
			e := int(C.GetLastError())
			return error_with_code(os.get_error_msg(e), e)
		}
	}
}
