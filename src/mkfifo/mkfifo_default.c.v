// mkfifo on unsupported platforms
fn do_mkfifo(pathname string, mode u32) int {
	return -1
}
