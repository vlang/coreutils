$if macos {
	fn C.mkfifo(const_ &char, u16) int
} $else {
	fn C.mkfifo(const_ &char, u32) int
}

fn do_mkfifo(pathname string, mode u32) int {
	$if macos {
		return C.mkfifo(pathname.str, u16(mode))
	} $else {
		return C.mkfifo(pathname.str, mode)
	}
}
