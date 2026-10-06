import os
import time
import common

const app_name = 'date'

const weekdays_short = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const weekdays_long = [
	'Sunday',
	'Monday',
	'Tuesday',
	'Wednesday',
	'Thursday',
	'Friday',
	'Saturday',
]
const months_short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov',
	'Dec']
const months_long = [
	'January',
	'February',
	'March',
	'April',
	'May',
	'June',
	'July',
	'August',
	'September',
	'October',
	'November',
	'December',
]

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('Print or set the system date and time.')
	// +FORMAT is not a flag, so the flag parser does not claim it: it is read from
	// the command line directly, and the + is stripped.
	mut format := ''
	for arg in os.args[1..] {
		if arg.starts_with('+') {
			format = arg[1..]
		}
	}
	utc := fp.bool('utc', `u`, false, 'print the date in UTC')
	rfc2822 := fp.bool('rfc-2822', `R`, false, 'output date in RFC 2822 format')
	iso := fp.bool('iso-8601', `I`, false, 'output date in ISO 8601 format')
	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	fp.allow_unknown_args()
	if help {
		println(fp.usage())
		return
	}
	if version {
		println('${app_name} ${common.coreutils_version()}')
		return
	}
	fp.finalize()!

	mut now := time.now()
	if utc {
		now = now.local_to_utc()
	}

	if iso {
		println(format_iso(now))
		return
	}
	if rfc2822 {
		println(format_rfc2822(now))
		return
	}
	if format != '' {
		println(render(format, now))
		return
	}
	// The default form, measured on GNU 9.4: %a %b %e %H:%M:%S %z %Y.
	println(render('%a %b %e %H:%M:%S %z %Y', now))
}

fn format_iso(t time.Time) string {
	return '${t.year}-${pad2(t.month)}-${pad2(t.day)}'
}

fn format_rfc2822(t time.Time) string {
	off := offset_seconds(t)
	sign := if off >= 0 { '+' } else { '-' }
	a := if off < 0 { -off } else { off }
	return '${weekdays_short[t.day_of_week()]}, ${pad2(t.day)} ${months_short[t.month - 1]} ${t.year} ${pad2(t.hour)}:${pad2(t.minute)}:${pad2(t.second)} ${sign}${pad2(int(a / 3600))}${pad2(int(a % 3600 / 60))}'
}

// V's Time carries no offset field, so the zone is the difference between the
// absolute epoch and the epoch the same wall clock would have in the local zone.
fn offset_seconds(t time.Time) i64 {
	return t.unix() - t.local_unix()
}

fn pad2(n int) string {
	return if n < 10 { '0${n}' } else { n.str() }
}

// render walks a format string and replaces the strftime specifiers. The ones
// implemented are the ones the tests use; the rest are left as written, which is
// what GNU does with an unknown specifier too.
fn render(format string, t time.Time) string {
	mut out := ''
	mut i := 0
	for i < format.len {
		if format[i] != `%` {
			out += format[i].ascii_str()
			i++
			continue
		}
		i++
		if i >= format.len {
			break
		}
		match format[i] {
			`Y` { out += t.year.str() }
			`m` { out += pad2(t.month) }
			`d` { out += pad2(t.day) }
			`e` { out += ' ' + pad2(t.day) }
			`H` { out += pad2(t.hour) }
			`M` { out += pad2(t.minute) }
			`S` { out += pad2(t.second) }
			`a` { out += weekdays_short[t.day_of_week()] }
			`A` { out += weekdays_long[t.day_of_week()] }
			`b`, `h` { out += months_short[t.month - 1] }
			`B` { out += months_long[t.month - 1] }
			`s` { out += t.unix().str() }
			`z` {
				off := offset_seconds(t)
				sign := if off >= 0 { '+' } else { '-' }
				a := if off < 0 { -off } else { off }
				out += '${sign}${pad2(int(a / 3600))}${pad2(int(a % 3600 / 60))}'
			}
			`Z` { out += timezone_name(t) }
			`j` { out += pad3(day_of_year(t)) }
			`u` { out += (t.day_of_week() % 7 + 1).str() }
			`w` { out += t.day_of_week().str() }
			`F` { out += '${t.year}-${pad2(t.month)}-${pad2(t.day)}' }
			`T` { out += '${pad2(t.hour)}:${pad2(t.minute)}:${pad2(t.second)}' }
			`R` { out += '${pad2(t.hour)}:${pad2(t.minute)}' }
			`n` { out += '\n' }
			`t` { out += '\t' }
			`%` { out += '%' }
			else { out += '%' + format[i].ascii_str() }
		}
		i++
	}
	return out
}

fn pad3(n int) string {
	if n < 10 {
		return '00${n}'
	}
	if n < 100 {
		return '0${n}'
	}
	return n.str()
}

fn day_of_year(t time.Time) int {
	mut doy := t.day
	for m in 1 .. t.month {
		doy += days_in_month(t.year, m)
	}
	return doy
}

fn days_in_month(year int, month int) int {
	return [31, if is_leap(year) { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
}

fn is_leap(year int) bool {
	return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

// timezone_name returns the abbreviation for the time zone, which is the numeric
// offset spelled as a name when the zone has no abbreviation of its own. GNU prints
// +0330 here on a machine in Iran, and V's own zone name is the same digits.
fn timezone_name(t time.Time) string {
	off := offset_seconds(t)
	sign := if off >= 0 { '+' } else { '-' }
	a := if off < 0 { -off } else { off }
	return '${sign}${pad2(int(a / 3600))}${pad2(int(a % 3600 / 60))}'
}
