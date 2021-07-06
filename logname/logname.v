import os
import flag

/* logname
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

fn error_exit(errors ...string) {
	for error in errors {
		eprintln(error)
	}
	exit(1) 	
}

/*
** Standard function to perform basic flag parsing an help and version processing
** params: args - string array (should usually be os.args in main function)
** returns: FlagParser object reference - may be used if other options are there
** logic: Creates a parser with given arguments. Checks if --help or --version flag are present, and prints and exits if yes
*/

fn get_flags_help_version(args []string, app_name string, version_str string, free_args_min int, free_args_max int) &flag.FlagParser{
	// Flags
	mut fp := flag.new_flag_parser(os.args)
	fp.application(app_name)
	fp.limit_free_args(free_args_min,free_args_max)
	fp.version(version_str)	// Preferably take from common version constant, should be updated
	// exec := fp.args[0]
	// println(exec)

	// --help and --version are standard flags for coreutils programs
	help := fp.bool('help',0,false,'display this help and exit')
	version := fp.bool('version',0,false,'output version information and exit')
	
	if help{
		println(fp.usage())
		exit(0)
	}
	if version {
		println('version')
		exit(0)
	}

	fp.skip_executable()

	fp.finalize() or {
		error_exit(err.str(),fp.usage())
	}

	return fp
}

fn main() {
	// No options used here, so don't store returned parser
	get_flags_help_version(os.args, 'logname', '0.0.1', 0, 0)

	// Main functionality

	// Uses C.getlogin internally
	lname := os.loginname()
	if lname == '' {
		// C.getlogin failed
		error_exit('no login name')
	}
	println(lname)
}
