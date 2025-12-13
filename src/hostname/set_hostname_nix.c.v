#include <unistd.h>

fn C.sethostname(&char, int) int

// Set hostname on linux hosts
// return 0 if success
fn set_hostname(hostname string) int {
	if hostname.len > 256 {
		return -1
	}
	return C.sethostname(&char(hostname.str), hostname.len)
}

// Fancy wrapper for error codes if set_hostname returns -1
fn errno_get_hostname() HostnameError {
	return match C.errno {
		C.EFAULT { HostnameError.invalid_address }
		C.EINVAL { HostnameError.invalid_value }
		C.EPERM { HostnameError.missing_permissions }
		else { HostnameError.unknown }
	}
}
