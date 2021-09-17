import os
import common

#include <pwd.h>

struct C.passwd {
	pw_name &char
}

fn C.getpwuid(uid int) &C.passwd

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('whoami')
	fp.description('Print the user name associated with the current effective user ID.')
	fp.description('Same as id -un.')
	fp.limit_free_args_to_exactly(0) ?
	fp.remaining_parameters()
	uid := os.geteuid()
	if uid == -1 {
		common.exit_with_error_message('whoami', 'no user name')
	}
	pwd := C.getpwuid(uid)
	username := unsafe { cstring_to_vstring(pwd.pw_name) }
	println(username)
}
