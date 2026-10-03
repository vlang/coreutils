import common

// `struct utmpx` is picked up from <utmpx.h> via common/readutmp_nix.c.v. A
// hand written copy here listed only the fields it needed and dropped the
// fixed size char arrays, so its element size did not match the C struct.

fn utmp_users(filename &char) []string {
	mut utmp_buf := []C.utmpx{}
	mut names := []string{}
	common.read_utmp(filename, mut utmp_buf, .user_process)
	unsafe {
		for u in utmp_buf {
			names << cstring_to_vstring(&u.ut_user[0])
		}
	}
	// Obtain sorted order as GNU coreutils
	names.sort()
	return names
}
