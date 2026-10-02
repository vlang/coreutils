import math
import os
import regex
import time
import common

const cmd_ns = 'sleep'

// max_duration is the largest sleep time.Duration we are willing to hand to
// time.sleep(), and max_sleep_seconds is that same value expressed in seconds.
const max_duration = time.Duration(max_i64)
const max_sleep_seconds = 9223372036.854776

// <stdlib.h>
// str="-1.8e+308", ret = -inf, endptr => NULL
// str="1.8e+308", ret = +inf, endptr => NULL
// str="A1", ret = 0, endptr => "A1"
// str="1.2s", ret = 1.2, endptr => "s"

// apply_unit converts the passed number to seconds
fn apply_unit(n f64, unit string) !f64 {
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

fn is_decimal(s string) bool {
	mut re := regex.regex_opt(r'^[-+]?[0-9]+([.][0-9]+)?([eE][-+][0-9]+)?$') or { panic(err) }
	return re.matches_string(s)
}

fn f64_to_normal_string(n f64) string {
	val := '${n}'.trim_right('.0')
	return if val.len > 0 { val } else { '0' }
}

fn invalid_time_interval(n f64, unit string) string {
	return invalid_time_interval_argument('${f64_to_normal_string(n)}${unit}')
}

fn invalid_time_interval_argument(s string) string {
	return "${cmd_ns}: invalid time interval '${s}'"
}

// seconds_to_duration converts a possibly infinite number of seconds
// into a time.Duration. A Duration is an integer nanosecond count, so
// saturate instead of overflowing: an unbounded sleep must keep waiting
// rather than wrap around to (near) zero.
fn seconds_to_duration(seconds f64) time.Duration {
	nanoseconds := seconds * 1e9
	// `!(x < y)` also catches NaN and +inf, both of which must saturate
	if !(nanoseconds < max_sleep_seconds) {
		return max_duration
	}
	if nanoseconds <= 0.0 {
		return 0
	}
	return time.Duration(nanoseconds)
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
		suffix := if arg.len > 1 {
			c := arg[arg.len - 1..]
			if ['s', 'm', 'h', 'd'].contains(c) {
				c
			} else {
				''
			}
		} else {
			''
		}
		n_str := arg.trim_string_right(suffix)
		if !(n_str == 'inf' || n_str == 'infinity') && !is_decimal(n_str) {
			eprintln(invalid_time_interval_argument(arg))
			ok = false
			continue
		}
		n := if n_str == 'inf' || n_str == 'infinity' { math.inf(1) } else { n_str.f64() } // unsafe { C.strtold(&char(arg.str), &endptr) }
		unit := suffix
		if n < 0 {
			eprintln(invalid_time_interval(n, unit))
			ok = false
			continue
		}
		if s := apply_unit(n, unit) {
			seconds += s
		} else {
			eprintln(err.msg())
			ok = false
		}
	}
	if !ok {
		common.exit_with_error_message(cmd_ns, '')
	}
	// if seconds = +inf, it would not sleep
	// but original `sleep` would sleep
	t := time.ticks()
	time.sleep(seconds_to_duration(seconds))
	$if trace_sleep_ticks ? {
		println(time.ticks() - t)
	}
}
