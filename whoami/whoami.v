import os

fn try(arg string) string {
	return 'whoami: unknown argument: $arg\nUse whoami --help to see options'
}
fn unrec(arg string) string {
	return 'whoami: unrecognized option $arg\nUse whoami --help to see options'
}
fn error_exit(error string) {
	eprintln(error)
	exit(1) 
}
fn main() {
	usage := 'Usage: whoami [OPTION]. [OPTION] can be --help, --version'
	version := 'whoami (V coreutils) 0.0.1'
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
	user := os.loginname()
	if user == '' {
		// C.getlogin failed
		error_exit('no user name')
	}
	println(user)
}
