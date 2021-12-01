#include <unistd.h>

fn C.sethostname(&char, int) int

// Error enum
pub enum HostnameErrno {
	invalid_address
	invalid_value
	missing_permissions
	unknown
}

// Set hostname on linux hosts
// return 0 if success
fn set_hostname(hostname string) int {
	if hostname.len > 256 {
		return -1
	}

	hostname_arr := unsafe { malloc(hostname.len) + 1 }

	unsafe {
		for i in 0 .. hostname.len {
			hostname_arr[i] = hostname[i]
		}
		hostname_arr[hostname.len] = 0
	}
	return C.sethostname(hostname_arr, hostname.len)
}

// Fancy wrapper for error codes if set_hostname returns -1
fn errno_get_hostname() HostnameErrno {
	return match C.errno {
		C.EFAULT { HostnameErrno.invalid_address }
		C.EINVAL { HostnameErrno.invalid_value }
		C.EPERM { HostnameErrno.missing_permissions }
		else { HostnameErrno.unknown }
	}
}
