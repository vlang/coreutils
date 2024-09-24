// mkfifo on unsupported platforms
fn mkfifo(pathname string, mode int) int {
	return -1
}
