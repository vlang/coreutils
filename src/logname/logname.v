import os
import flag

/*
The following block has been created in this file, but should be extracted to a common module for use by all utils
*/

const (
	version_str = 'V Coreutils 0.0.1'
)

// A default error exit, when code is not important
fn error_exit(errors ...string) {
	error_exit_code(1, ...errors)
}

// Use only if error code is important (some semantic meaning to particular codes)
fn error_exit_code(code int, errors ...string) {
	for error in errors {
		eprintln(error)
	}
	exit(code)
}

// Use if successful exit
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}

/*
** Standard function to perform basic flag parsing an help and version processing
** params: args - string array (should usually be os.args in main function)
** returns: FlagParser object reference, exec name
** logic: Creates a parser with given arguments. Checks if --help or --version flag are present, and prints and exits if yes
*/

fn flags_common(args []string, app_name string, free_args_min int, free_args_max int) ?(&flag.FlagParser, string) {
	// Flags
	mut fp := flag.new_flag_parser(os.args)
	fp.application(app_name)
	fp.limit_free_args(free_args_min, free_args_max) ?
	fp.version(version_str) // Preferably take from common version constant, should be updated regularly
	fp.description('Tool to display login name')
	exec := fp.args[0]

	// println(exec)

	fp.skip_executable()

	return fp, exec
}

// Use if no arguments are taken
fn flags_common_no_args(args []string, app_name string) ?(&flag.FlagParser, string) {
	return flags_common(args, app_name, 0, 0)
}

/*
End of common block
*/

/*
logname
** VinWare, 2021-07-05 05:00:00 UTC
**
** Basic implementation of logname
** Does not specify ENV variables
** Follows POSIX (uses C getlogin)
**
** Remaining issues:
** Standard error messages - Ongoing
** Standard way to take arguments - Solved by using flags module
*/

fn main() {
	// Exec is not needed
	mut fp, _ := flags_common_no_args(os.args, 'logname') ?

	fp.finalize() or { error_exit(err.str(), fp.usage()) }

	// Main functionality

	// Uses C.getlogin internally
	lname := os.loginname()
	if lname == '' {
		// C.getlogin failed
		error_exit('no login name')
	}

	success_exit(lname)
}
