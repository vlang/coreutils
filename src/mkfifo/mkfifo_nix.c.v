fn C.mkfifo(&char, int) int

fn mkfifo(pathname string, mode u32) int {
	return C.mkfifo(pathname.str, mode)
}
