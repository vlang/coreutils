import os

const cmd_ns = 'printenv'

const zero_byte = byte(0).ascii_str()

/*
fn try(arg string) string {
	return '$cmd_ns: unknown argument: $arg\nUse $cmd_ns --help to see options'
}*/

fn unrec(arg string) string {
	return '$cmd_ns: unrecognized option $arg\nUse $cmd_ns --help to see options'
}

fn error_exit(error string) {
	eprintln(error)
	exit(1)
}

fn print_avliable_params() {
	mut entries := map{
		'--help':    'display this help and exit'
		'--version': 'output version information and exit'
	}
	// Other avliable parameters
	entries['-0, --null'] = 'end each output line with NUL, not newline'
	// Print avliable parameters
	println('Options:')
	for param, desp in entries {
		println('\t${param:-16} $desp')
	}
}

// Exit status:
// 0 if all variables specified were found
// 1 if at least one specified variable was not found
// 2 if a write error occurred
fn main() {
	usage := 'Usage: $cmd_ns [OPTION]... [VARIABLE]...\n'
	version := '$cmd_ns (V coreutils) 0.0.1'
	args := os.args[1..]

	mut nul_terminate := false
	// Parameters provided
	if args.len > 0 {
		option := args[0]
		match option {
			'--help' {
				println(usage)
				print_avliable_params()
				exit(0)
			}
			'--version' {
				println(version)
				exit(0)
			}
			'--null', '-0' {
				nul_terminate = true
			}
			else {
				if option[0..1] == '-' {
					error_exit(unrec(option))
				}
			}
		}
	}

	// Main functionality
	mut vars := []string{}
	if nul_terminate {
		vars << args[1..]
	} else {
		vars << args
	}
	if vars.len == 0 {
		// TODO : resolve the issue about
		// different output order from the original printenv
		for k, v in os.environ() {
			mut s := '$k=$v'
			if nul_terminate {
				print(s)
				print(zero_byte)
			} else {
				println(s)
			}
		}
	} else {
		mut code := 0 // exit code
		for k in vars {
			mut v := os.getenv(k)
			if v == '' {
				code = 1 // at least one specified variable was not found
				continue
			}
			if nul_terminate {
				print(v)
				print(zero_byte)
			} else {
				println(v)
			}
		}
		exit(code)
	}
}
