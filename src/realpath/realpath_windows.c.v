fn C.CreateFileW(lpFilename &u16, dwDesiredAccess u32, dwShareMode u32, lpSecurityAttributes &u16, dwCreationDisposition u32, dwFlagsAndAttributes u32, hTemplateFile voidptr) voidptr
fn C.GetFinalPathNameByHandleW(hFile voidptr, lpFilePath &u16, nSize u32, dwFlags u32) u32
fn C.GetFileAttributesW(lpFilename &u16) u32
fn C.GetLastError() u32

const max_path_buffer_size = u32(512)

const file_attribute_reparse_point = u32(0x400)
const invalid_file_attributes = u32(0xffffffff)

fn is_link(path string) bool {
	attrs := unsafe { C.GetFileAttributesW(&u16(path.to_wide())) }
	return attrs != invalid_file_attributes && (attrs & file_attribute_reparse_point) != 0
}

fn win32_error() !string {
	code := int(C.GetLastError())
	return error('the system reported error ${code}')
}

fn do_readlink(path string) !string {
	file := C.CreateFile(path.to_wide(), 0x80000000, 1, 0, 3, 0x80, 0)
	if file != voidptr(-1) {
		defer {
			C.CloseHandle(file)
		}
		final_path := [max_path_buffer_size]u8{}
		final_len := C.GetFinalPathNameByHandleW(file, unsafe { &u16(&final_path[0]) },
			max_path_buffer_size, 0)
		if final_len == 0 {
			return win32_error()
		}
		if final_len < max_path_buffer_size {
			sret := unsafe { string_from_wide2(&u16(&final_path[0]), int(final_len)) }
			defer {
				unsafe { sret.free() }
			}
			assert sret[0..4] == r'\\?\'
			sret_slice := sret[4..]
			res := sret_slice.clone()
			return res
		} else {
			return error('Final path length (${final_len}) exceeds buffer length (${max_path_buffer_size}).')
		}
	} else {
		return win32_error()
	}
}
