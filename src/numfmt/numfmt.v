import os
import strconv
import math

struct App {
mut:
	exit_code int
}

fn main() {
	mut app := App{}
	options := get_options()
	if options.numbers.len == 0 {
		from_stdin(mut app, options)
	} else {
		println(do_numfmt(options.numbers, mut app, options))
	}
	exit(app.exit_code)
}

fn from_stdin(mut app App, options Options) {
	mut header := options.header
	for {
		line := os.get_line()
		header -= 1
		if header > 0 {
			println(line)
			continue
		}
		if line.len == 0 {
			break
		}
		results := do_numfmt(line.split(options.delimiter), mut app, options)
		println(results)
	}
}

fn do_numfmt(numbers []string, mut app App, options Options) string {
	mut results := []string{}
	for i, number in numbers {
		match i in options.fields.map(it - 1) {
			true {
				results << numfmt(number, mut app, options) or {
					handle_error(err.msg(), mut app, options)
				}
			}
			else {
				results << number
			}
		}
	}
	return results.join(options.delimiter)
}

fn numfmt(number string, mut app App, options Options) !string {
	// convert string to number
	num_part, scale_part := split_parts(number)
	num := strconv.atof64(num_part)!
	pow := suffix_to_power(scale_part)!
	sca := scale_number(num, pow, options)
	n := sca * options.from_unit / options.to_unit
	// apply formating
	mut result := match true {
		options.pformat.len != 0 { unsafe { strconv.v_sprintf(options.pformat, n) } }
		options.grouping { commaize(n) }
		options.to == 'none' { n.str() }
		else { num_to_str(n, options) or { handle_error(err.msg(), mut app, options) } }
	}
	if options.suffix.len != 0 {
		result += options.suffix
	}
	if options.padding != 0 {
		result = strconv.format_str(result, strconv.BF_param{
			len0:  math.abs(options.padding)
			align: if options.padding > 0 { .right } else { .left }
		})
	}
	return result
}

fn split_parts(number string) (string, string) {
	n_array := number.bytes()
	for idx := 0; idx < number.len; idx++ {
		c := n_array[idx]
		if idx == 0 {
			if c == `-` || c == `+` {
				continue
			}
		}
		if c.is_digit() || c == `.` || c == `,` {
			continue
		}
		return number[..idx], number[idx..]
	}
	return number, ''
}

enum Unit {
	@none
	auto
	si
	iec
	iec_i
}

fn suffix_to_power(suffix string) !int {
	return match suffix {
		'' { 0 }
		'K' { 3 }
		'M' { 6 }
		'G' { 9 }
		'T' { 12 }
		'P' { 15 }
		'E' { 18 }
		'Z' { 21 }
		'Y' { 24 }
		else { error('unknown suffix ${suffix}') }
	}
}

fn power_to_suffix(power u64) !string {
	return match power {
		0 { '' }
		3 { 'K' }
		6 { 'M' }
		9 { 'G' }
		12 { 'T' }
		15 { 'P' }
		18 { 'E' }
		21 { 'Z' }
		24 { 'Y' }
		else { error('unknown power ${power}') }
	}
}

fn num_to_str(num f64, options Options) !string {
	return match options.to {
		'si' { readable_size(num, Unit.si, options.round)! }
		'iec' { readable_size(num, Unit.iec, options.round)! }
		'iec-i' { readable_size(num, Unit.iec_i, options.round)! }
		else { error('unknown format ${options.to}') }
	}
}

fn readable_size(size f64, unit Unit, rounding string) !string {
	kb := if unit == .iec || unit == .iec_i { f64(1024) } else { f64(1000) }
	mut sz := size
	suffixes := match unit {
		.si { ['', 'k', 'm', 'g', 't', 'p', 'e', 'z'] }
		.iec { ['', 'K', 'M', 'G', 'T', 'P', 'E', 'Z'] }
		.iec_i { ['', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi'] }
		else { [''] }
	}
	if suffixes == [''] {
		return error('invalid unit ${unit}')
	}
	for suffix in suffixes {
		if sz < kb {
			sc := if sz < 10 { 10.0 } else { 1.0 }
			rounded := round(sz * sc, rounding) / sc
			show_decimal := rounded != 0 && math.abs(rounded) < 10
			readable := match show_decimal {
				true { '${rounded:.1f}' }
				else { '${rounded:.0f}' }
			}
			return '${readable}${suffix}'
		}
		sz /= kb
	}
	return size.str()
}

fn scale_number(num f64, pow int, options Options) i64 {
	n := num * math.pow10(pow)
	return round_from_zero(n)
}

fn commaize(num f64) string {
	str := strconv.f64_to_str_l(num)
	n, _ := str.split_once('.') or { return 'oops' }
	mut result := ''
	for i, c in n.reverse() {
		if i != 0 && i % 3 == 0 && c.is_digit() {
			result += ','
		}
		result += c.ascii_str()
	}
	return result.reverse()
}

fn round(val f64, rounding string) i64 {
	rval := match rounding {
		// vfmt off
		'from-zero'	{ round_from_zero(val) }
		'towards-zero'	{ round_towards_zero(val) }
		'nearest'	{ round_nearest(val) }
		'up'		{ round_ceiling(val) }
		'down'		{ round_floor(val) }
		else 		{ 0 }
		// vfmt on
	}
	// println('${val}, ${rval}')
	return rval
}

fn round_ceiling(val f64) i64 {
	return i64(math.ceil(val))
}

fn round_floor(val f64) i64 {
	return i64(math.floor(val))
}

fn round_from_zero(val f64) i64 {
	return if val < 0 { round_floor(val) } else { round_ceiling(val) }
}

fn round_towards_zero(val f64) i64 {
	return i64(val)
}

fn round_nearest(val f64) i64 {
	return if val < 0 { round_towards_zero(val - 0.5) } else { round_towards_zero(val + 0.5) }
}

fn handle_error(msg string, mut app App, options Options) string {
	match true {
		// Processing stops at the first error
		options.invalid == 'abort' {
			exit_message(msg, 2)
		}
		// Conversion errors are reported to STDERR, always return 0
		options.invalid == 'warn' {
			eprintln(msg)
		}
		// Processing continues
		options.invalid == 'fail' {
			eprintln(msg)
			app.exit_code = 2
		}
		options.invalid == 'ignore' {}
		else {
			exit_message('assert', 2)
		} // should never happen
	}
	return ''
}

fn print_space() {
	print_character(` `)
}

@[noreturn]
fn exit_message(msg string, exit_code int) {
	eprintln(msg)
	exit(exit_code)
}
