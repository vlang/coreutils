import common

pub struct C.utmpx {
	ut_type i16   // Type of login.
	ut_pid  int   // Process ID of login process.
	ut_line &char // Devicename.
	ut_id   &char // Inittab ID.
	ut_user &char // Username.
}

fn utmp_users(filename &char) []string {
	mut utmp_buf := []C.utmpx{}
	mut users := []string{}
	common.read_utmp(filename, mut utmp_buf, .user_process)
	unsafe {
		for u in utmp_buf {
			users << cstring_to_vstring(u.ut_user)
		}
	}
	// Obtain sorted order as GNU coreutils
	users.sort()
	return users
}
