module logname

import flag
import os

/*
The following block has been created in this file, but should be extracted to a common module for use by all utils
*/

const version_str = 'V Coreutils 0.0.1'

/*
** Standard function to perform basic flag parsing an help and version processing
** params: args - string array (should usually be os.args in main function)
** returns: FlagParser object reference, exec name
** logic: Creates a parser with given arguments. Checks if --help or --version flag are present, and prints and exits if yes
*/

fn flags_common(args []string, app_name string, free_args_min int, free_args_max int) !(&flag.FlagParser, string) {
	// Flags
	// The parser is built from the args it is given, not from os.args. It used to
	// read os.args directly despite taking the parameter, which meant the tool
	// only behaved correctly when invoked as its own binary - and parsed the
	// wrong argv when called any other way.
	mut fp := flag.new_flag_parser(args)
	fp.application(app_name)
	fp.limit_free_args(free_args_min, free_args_max)!
	fp.version(version_str) // Preferably take from common version constant, should be updated regularly
	fp.description('Tool to display login name')
	exec := fp.args[0]

	fp.skip_executable()

	return fp, exec
}

// Use if no arguments are taken
fn flags_common_no_args(args []string, app_name string) !(&flag.FlagParser, string) {
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

// run is the entry point shared by the standalone binary and the multicall
// binary, so both dispatch through the same code.
pub fn run(args []string) int {
	// Exec is not needed
	mut fp, _ := flags_common_no_args(args, 'logname') or {
		eprintln(err)
		return 1
	}

	fp.finalize() or {
		eprintln(err)
		eprintln(fp.usage())
		return 1
	}

	// Main functionality

	// Uses C.getlogin internally
	lname := os.loginname() or { '' }
	if lname == '' {
		// C.getlogin failed
		eprintln('logname: no login name')
		return 1
	}

	println(lname)
	return 0
}
