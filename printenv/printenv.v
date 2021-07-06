import os

const cmd_ns = 'printenv'

fn try(arg string) string {
	return '$cmd_ns: unknown argument: $arg\nUse $cmd_ns --help to see options'
}

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
	entries['--null'] = 'end each output line with NUL, not newline'
	// Print avliable parameters
	println('Options:')
	for param, desp in entries {
		println('\t${param:-16} $desp')
	}
}

fn main() {
	usage := 'Usage: $cmd_ns [OPTION]... [VARIABLE]...\n'
	version := '$cmd_ns (V coreutils) 0.0.1'
	args := os.args[1..]
	params := args.filter(it.len > 2 && it[0..2] == '--')
	if params.len > 0 {
		// Parameters provided
		match params[0] {
			'--help' {
				println(usage)
				print_avliable_params()
				exit(0)
			}
			'--version' {
				println(version)
				exit(0)
			}
			'--null' { // -0
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
}
