module common

#include <utmp.h>
#include <utmpx.h>
#include <errno.h>

// TODO: conflicts with `timeval` in <time.h>
// <bits/types/struct_timeval.h>
/*
struct C.timeval {
	tv_sec  i64 // Seconds.
	tv_usec i64 // Microseconds.
}*/

// <time.h>
struct C.timeval {
	tv_sec  u64 // Seconds.
	tv_usec u64 // Microseconds.
}

struct C.utmpx {
	ut_type    i16       // Type of login.
	ut_pid     int       // Process ID of login process.
	ut_line    [32]char  // Devicename.
	ut_id      [4]char   // Inittab ID.
	ut_user    [32]char  // Username.
	ut_host    [256]char // Hostname for remote login.
	ut_tv      C.timeval // TODO: Declare sub struct correctly
	ut_addr_v6 [4]int    // Internet address of remote host.
}

// sets the name of the utmp-format file for the other utmp functions to access.
fn C.utmpxname(&char) int

// rewinds the file pointer to the beginning of the utmp file.
fn C.setutxent()

// reads a line from the current file position in the utmp file.
fn C.getutxent() &C.utmpx

// closes the utmp file.
fn C.endutxent()

pub const utmp_file_charptr = &char(C._PATH_UTMP)

pub const wtmp_file_charptr = &char(C._PATH_WTMP)

// Options for read_utmp.
pub enum ReadUtmpOptions {
	undefined = 0
	check_pids = 1
	user_process = 2
}

// readutmp.h : IS_USER_PROCESS(U)
pub fn is_user_process(u &C.utmpx) bool {
	// C.USER_PROCESS = 7
	return !isnil(u.ut_user[0]) && u.ut_type == C.USER_PROCESS
}

fn desirable_utmp_entry(u &C.utmpx, options ReadUtmpOptions) bool {
	user_proc := is_user_process(u)
	if (options == ReadUtmpOptions.user_process) && !user_proc {
		return false
	}
	if (options == ReadUtmpOptions.check_pids) && user_proc && 0 < u.ut_pid
		&& (C.kill(u.ut_pid, 0) < 0 && C.errno == C.ESRCH) {
		return false
	}
	return true
}

// Read the utmp entries corresponding to file into freshly-malloc'd storage.
pub fn read_utmp(file &char, mut utmp_buf []C.utmpx, options ReadUtmpOptions) {
	C.utmpxname(file)
	C.setutxent()
	mut u := C.getutxent()
	for !isnil(u) {
		if desirable_utmp_entry(u, options) {
			// TODO : solve `cannot convert 'struct <anonymous>' to 'struct timeval'`
			// println(u)
			utmp_buf << *u
		}
		u = C.getutxent()
	}
	C.endutxent()
}
