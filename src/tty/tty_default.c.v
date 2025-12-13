import common

const c_stdin = 1

pub fn isatty(fd int) !bool {
	return error_with_code('platform not supported', common.err_platform_not_supported)
}

pub fn ttyname(fd int) !string {
	return error_with_code('platform not supported', common.err_platform_not_supported)
}
