import os

fn C.CreateFileW(lpFilename &u16, dwDesiredAccess u32, dwShareMode u32, lpSecurityAttributes &u16, dwCreationDisposition u32, dwFlagsAndAttributes u32, hTemplateFile voidptr) voidptr
fn C.GetFinalPathNameByHandleW(hFile voidptr, lpFilePath &u16, nSize u32, dwFlags u32) u32
fn C.GetFileAttributesW(lpFileName &u16) u32
fn C.GetLastError() u32

const max_path_buffer_size = u32(512)

// file_attribute_reparse_point is how Windows says a path is a link or a junction,
// and invalid_file_attributes is what GetFileAttributesW answers for a path that
// does not exist.
const file_attribute_reparse_point = u32(0x400)
const invalid_file_attributes = u32(0xffffffff)

// is_link is the question GetFinalPathNameByHandleW cannot answer. That call
// resolves any file, so readlink on a plain file used to print that file's own
// canonical path and exit 0, where GNU prints nothing and exits 1. Measured
// against uutils 0.0.17 and GNU 8.32 on this machine, `readlink <a plain file>`
// gives an empty line and status 1 from both.
fn is_link(path string) bool {
	attrs := unsafe { C.GetFileAttributesW(&u16(path.to_wide())) }
	return attrs != invalid_file_attributes && (attrs & file_attribute_reparse_point) != 0
}

// win32_error is the failure path for a handle the system would not give us.
//
// It used to be `os.error_win32()`, which is a panic rather than an error unless
// e.code is set first, and readlink reached it for every path it could not open -
// a directory, a name that is not there - which is to say for most of what the
// tests hand it. The code is carried in the message because this V has no
// os.Err to put it in.
fn win32_error() !string {
	code := int(C.GetLastError())
	return error('the system reported error ${code}')
}

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
			return win32_error()
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
		return win32_error()
	}
}
