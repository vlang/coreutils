import os
import common
import time

const cmd_ns = 'sleep'

// <stdlib.h>
// str="-1.8e+308", ret = -inf, endptr => NULL
// str="1.8e+308", ret = +inf, endptr => NULL
// str="A1", ret = 0, endptr => "A1"
// str="1.2s", ret = 1.2, endptr => "s"
fn C.strtold(str &char, endptr &&char) f64

// apply_unit converts the passed number to seconds
fn apply_unit(n f64, unit string) ?f64 {
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
		else {}
	}
	return error(invalid_time_interval(n, unit))
}

fn invalid_time_interval(n f64, unit string) string {
	return "$cmd_ns: invalid time interval '$n$unit'"
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(cmd_ns)
	fp.arguments_description('| NUMBER[smhd]...')
	fp.description('Pause for NUMBER (integer ot floating-point number) seconds.')
	fp.description('"s" for seconds (the default), "m" for minutes, "h" for hours or "d" for days.')
	fp.description('Pause for the amount of time specified by the sum of arguments.')
	args := fp.remaining_parameters()
	if args.len == 0 {
		common.exit_with_error_message(cmd_ns, 'missing operand')
	}

	// Main functionality
	mut ok := true
	mut seconds := f64(0)
	for arg in args {
		endptr := &char(0)
		n := unsafe { C.strtold(&char(arg.str), &endptr) }
		unit := unsafe { cstring_to_vstring(endptr) }
		if n < 0 || unit.len > 1 {
			eprintln(invalid_time_interval(n, unit))
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
		common.exit_with_error_message(cmd_ns, '')
	}
	// if seconds = +inf, it would not sleep
	// but orginal `sleep` would sleep
	t := time.ticks()
	time.sleep(seconds * time.second)
	$if trace_sleep_ticks ? {
		println(time.ticks() - t)
	}
}
