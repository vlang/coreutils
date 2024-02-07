fn do_sync(fd int) ! {
	return error_with_code('syncfs not available on this platform', 127)
}

fn do_fsync(fd int) ! {
	return error_with_code('fsync not available on this platform', 127)
}

fn do_fdatasync(fd int) ! {
	return error_with_code('fdatasync not available on this platform', 127)
}
