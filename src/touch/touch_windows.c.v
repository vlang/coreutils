// The handle is a voidptr because that is what vlib's C.CreateFileW returns;
// it used to return u32, and declaring the parameter as u32 is what made this
// file stop compiling on current V. A HANDLE is a pointer either way.
fn C.SetFileTime(hfile voidptr, const_creation_time voidptr, const_access_time voidptr, const_modification_time voidptr) bool

fn lutime(path string, acctime int, modtime int) ! {
	creation_time := t2filetime(-1)
	access_time := t2filetime(acctime)
	modification_time := t2filetime(modtime)
	path_wide := path.to_wide()
	f_handle := C.CreateFileW(path_wide, C.GENERIC_READ | C.GENERIC_WRITE,
		C.FILE_SHARE_DELETE | C.FILE_SHARE_READ | C.FILE_SHARE_WRITE, 0, C.OPEN_ALWAYS,
		C.FILE_ATTRIBUTE_NORMAL, 0)
	if f_handle == 0 {
		return error('invalid file handle')
	}
	defer {
		C.CloseHandle(f_handle)
	}
	if !C.SetFileTime(f_handle, &creation_time, &access_time, &modification_time) {
		return error('unable to set file times')
	}
}

fn t2filetime(t int) C._FILETIME {
	// See https://learn.microsoft.com/en-us/windows/win32/sysinfo/converting-a-time-t-value-to-a-file-time
	mut res := C._FILETIME{}
	if t == -1 {
		return res
	}
	mut n := u64(116444736000000000) + u64(10000000) * u64(t)
	res.dwLowDateTime = u32(n)
	res.dwHighDateTime = u32(n >> 32)
	return res
}
