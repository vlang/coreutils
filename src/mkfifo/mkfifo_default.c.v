// mkfifo on unsupported platforms
fn mkfifo(pathname string, mode u32) int {
	return -1
}
