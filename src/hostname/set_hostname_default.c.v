// Set hostname on unsupported platforms
fn set_hostname(hostname string) int {
	return -1
}

// The platform is not supported
fn errno_get_hostname() HostnameError {
	return HostnameError.unsupported
}
