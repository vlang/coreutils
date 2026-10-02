module common

#include <utmp.h>
#include <utmpx.h>
#include <errno.h>

// `struct utmpx` was previously declared twice, once here and once in
// src/users/users.c.v with a different (shorter) field list, which V rejects as
// a redeclaration. Declare it once, here, with the glibc layout.
//
// The fixed size fields are UT_LINESIZE/UT_NAMESIZE/UT_HOSTSIZE (32/32/256) and
// the element size has to match what getutxent() writes, because read_utmp()
// copies entries into a []C.utmpx.
pub struct C.exit_status {
	et_code u16
	et_term u16
}

pub struct C.utmpx {
	ut_type       i16           // Type of login.
	ut_pid        int           // Process ID of login process.
	ut_line       [32]u8        // Devicename.
	ut_id         [4]u8         // Inittab ID.
	ut_user       [32]u8        // Username.
	ut_host       [256]u8       // Hostname for remote login.
	ut_exit       C.exit_status // Exit status of the process.
	ut_session_id i32           // Session ID.
	ut_tv         C.timeval     // Time entry.
	ut_addr_v6    [4]i32        // Internet address of remote host.
	__unused      [20]u8        // Reserved.
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
	undefined    = 0
	check_pids   = 1
	user_process = 2
}

// readutmp.h : IS_USER_PROCESS(U)
pub fn is_user_process(u &C.utmpx) bool {
	// C.USER_PROCESS = 7
	unsafe {
		return !isnil(u.ut_user[0]) && u.ut_type == C.USER_PROCESS
	}
}

fn desirable_utmp_entry(u &C.utmpx, options ReadUtmpOptions) bool {
	user_proc := is_user_process(u)
	if options == ReadUtmpOptions.user_process && !user_proc {
		return false
	}
	if options == ReadUtmpOptions.check_pids && user_proc && 0 < u.ut_pid
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
