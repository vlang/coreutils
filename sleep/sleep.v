import os
import time { sleep }

const cmd_ns = 'sleep'

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
	// Print avliable parameters
	println('Options:')
	for param, desp in entries {
		println('\t${param:-16} $desp')
	}
}

// <stdlib.h>
// str="-1.8e+308", ret = -inf, endptr => NULL
// str="1.8e+308", ret = +inf, endptr => NULL
// str="A1", ret = 0, endptr => "A1"
// str="1.2s", ret = 1.2, endptr => "s"
fn C.strtold(str &char, endptr &&char) f64

// Exit status:
// 0 indicates success
// other indicates failure
fn main() {
	usage := 'Usage: $cmd_ns sleep NUMBER[smhd]...\n  or:  sleep OPTION\n'
	version := '$cmd_ns (V coreutils) 0.0.1'
	description := 'Pause for NUMBER (integer ot floating-point number) seconds.\n' +
		'"s" for seconds (the default), "m" for minutes, "h" for hours or "d" for days.\n' +
		'Pause for the amount of time specified by the sum of arguments.\n'
	args := os.args[1..]

	// Parameters provided
	if args.len > 0 {
		option := args[0]
		match option {
			'--help' {
				println(usage)
				println(description)
				print_avliable_params()
				exit(0)
			}
			'--version' {
				println(version)
				exit(0)
			}
			else {
				if option[0..1] == '-' {
					error_exit(unrec(option))
				}
			}
		}
	}

	// convert to seconds
	apply_unit := fn (n f64, unit string) ?f64 {
		match unit {
			's' {
				return n
			}
			'm' {
				return 60 * n
			}
			'h' {
				return 2000 * n
			}
			'd' {
				return 86400 * n
			}
			else {
				return error('invalid time interval $n$unit')
			}
		}
	}

	// Main functionality
	mut seconds := f64(0)
	for arg in args {
		endptr := &char(0)
		n := unsafe { C.strtold(&char(arg.str), &endptr) }
		unit := unsafe { cstring_to_vstring(endptr) }
		if n < 0 || unit.len > 1 {
			error_exit('invalid time interval $n$unit')
		}

		if s := apply_unit(n, unit) {
			seconds += s
		} else {
			error_exit(err.msg)
		}
	}
	sleep(seconds * 1e9) // in nanoseconds
}
