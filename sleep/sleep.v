import os
import flag
import time { sleep, ticks }

const cmd_ns = 'sleep'

/*
fn unrec(arg string) string {
	return '$cmd_ns: unrecognized option $arg\nUse $cmd_ns --help to see options'
}*/

fn error_exit(error string) {
	eprintln(error)
	println("Try '$cmd_ns --help' for more information.")
	exit(1)
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
	// Define options
	mut fp := flag.new_flag_parser(os.args)
	fp.application(cmd_ns)
	fp.version('(V coreutils) 0.0.1')
	fp.skip_executable()
	fp.arguments_description('| NUMBER[smhd]...')
	fp.description('Pause for NUMBER (integer ot floating-point number) seconds.\n' +
		'"s" for seconds (the default), "m" for minutes, "h" for hours or "d" for days.\n' +
		'Pause for the amount of time specified by the sum of arguments.\n')
	help_opt := fp.bool('help', 0, false, 'display this help and exit')
	version_opt := fp.bool('version', 0, false, 'output version information and exit')
	args := fp.finalize() or {
		error_exit(err.msg)
		exit(1)
	}
	if help_opt {
		println(fp.usage())
		exit(0)
	}
	if version_opt {
		println('$cmd_ns $fp.application_version')
		exit(0)
	}

	if args.len == 0 {
		error_exit('$cmd_ns: missing operand')
	}

	// convert to seconds
	apply_unit := fn (n f64, unit string) ?f64 {
		match unit {
			'', 's' {
				return n
			}
			'm' {
				return 60 * n
			}
			'h' {
				return 3600 * n
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
	mut ok := true
	mut seconds := f64(0)
	for arg in args {
		endptr := &char(0)
		n := unsafe { C.strtold(&char(arg.str), &endptr) }
		unit := unsafe { cstring_to_vstring(endptr) }
		if n < 0 || unit.len > 1 {
			eprintln('invalid time interval $n$unit')
			ok = false
			continue
		}
		if s := apply_unit(n, unit) {
			seconds += s
		} else {
			eprintln(err.msg)
			ok = false
		}
	}
	if !ok {
		error_exit("Try '$cmd_ns --help' for more information.")
	}
	// if seconds = +inf, it would not sleep
	// but orginal `sleep` would sleep
	t := ticks()
	sleep(seconds * 1e9) // in nanoseconds
	$if debug {
		println(ticks() - t)
	}
}
