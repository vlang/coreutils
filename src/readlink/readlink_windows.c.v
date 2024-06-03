import os

fn C.CreateFileW(lpFilename &u16, dwDesiredAccess u32, dwShareMode u32, lpSecurityAttributes &u16, dwCreationDisposition u32, dwFlagsAndAttributes u32, hTemplateFile voidptr) voidptr
fn C.GetFinalPathNameByHandleW(hFile voidptr, lpFilePath &u16, nSize u32, dwFlags u32) u32

const max_path_buffer_size = u32(512)

fn do_readlink(path string) !string {
	// gets handle with GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
	file := C.CreateFile(path.to_wide(), 0x80000000, 1, 0, 3, 0x80, 0)
	if file != voidptr(-1) {
		defer {
			C.CloseHandle(file)
		}
		final_path := [max_path_buffer_size]u8{}
		// https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfinalpathnamebyhandlew
		final_len := C.GetFinalPathNameByHandleW(file, unsafe { &u16(&final_path[0]) },
			max_path_buffer_size, 0)
		if final_len == 0 {
			return os.error_win32()
		}
		if final_len < max_path_buffer_size {
			sret := unsafe { string_from_wide2(&u16(&final_path[0]), int(final_len)) }
			defer {
				unsafe { sret.free() }
			}
			// remove '\\?\' from beginning (see link above)
			assert sret[0..4] == r'\\?\'
			sret_slice := sret[4..]
			res := sret_slice.clone()
			return res
		} else {
			return error('Final path length (${final_len}) exceeds buffer length (${max_path_buffer_size}).')
		}
	} else {
		return os.error_win32()
	}
}
