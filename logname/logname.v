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
** Standard error messages
** Standard way to take arguments
*/

fn try(arg string) string {
	line1 := 'Unknown argument: ' + arg
	line2 := 'Use logname --help to see options'
	return line1 + '\n' + line2
}
fn unrec(arg string) string {
	line1 := 'logname: unrecognized option ' + arg
	line2 := 'Use logname --help to see options'
	return line1 + '\n' + line2
}
fn error_exit(error string) {
	eprintln(error)
	exit(1) 	
}
fn main() {
	// Flags
	mut fp := flag.new_flag_parser(os.args)
	fp.application('logname')
	// fp.limit_free_args(0,0)
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
	lname := os.loginname()
	if lname == '' {
		error_exit('no login name')
	}
	println(lname)
}
fn old_main() {
	usage := 'Usage: logname [OPTION]. [OPTION] can be --help, --version'
	version := 'logname (V coreutils) 0.0.1'
	args := os.args[1..]
	params := args.filter(it.len > 2 && it[0..2] == '--')
	if params.len > 0 {
		// Parameters provided
		match params[0] {
			'--help' {
				println(usage)
				exit(0)
			}
			'--version' {
				println(version)
				exit(0)
			}
			else {
				error_exit(unrec(params[0]))
			}
		}
		exit(0)
	}
	if args.len > 0 {
		// Unnecessary argument
		error_exit(try(args[0]))
	} 
	// Main functionality
	// Internally uses C.getlogin
	lname := os.loginname()
	if lname == '' {
		// C.getlogin failed
		error_exit('no login name')
	}
	println(lname)
}
