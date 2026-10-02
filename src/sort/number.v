import math
import strconv

// A numeric prefix, as the -n, -g and -h orderings use it: the value found at
// the start of the key and the rest of the key from there.
struct NumberPrefix {
	value f64
	rest  string
}

// Numeric prefixes follow three different grammars, so that is how they are told
// apart. -g reads what strtod does, -h reads that plus a size suffix, and -n is
// the narrowest of the three.
enum NumberStyle {
	string
	general
	human
}

// number_prefix reads the numeric prefix of s in the given style.
fn number_prefix(s string, style NumberStyle) NumberPrefix {
	mut i := 0
	// A leading minus is read everywhere, a leading plus only by -g. GNU's probe
	// confirms it: with -n and with -h, "+5" weighs nothing and sorts as zero,
	// which puts it before "10" but after the letters.
	allow_plus := style == .general
	mut allow_sign := true
	mut allow_blanks := true
	mut negative := false

	for i < s.len {
		c := s[i]
		if allow_blanks && is_blank(c) {
			i++
			continue
		}
		if allow_sign && (c == `-` || (allow_plus && c == `+`)) {
			negative = c == `-`
			allow_sign = false
			allow_blanks = false
			i++
			continue
		}
		break
	}

	body_start := i
	// The words inf and nan are numbers to -g even though no digit starts them, so
	// they have to be recognised before the scan for digits, which would find
	// nothing and report the line as having no number at all.
	if style == .general {
		word := s[body_start..].to_lower()
		if word == 'inf' {
			return NumberPrefix{
				value: math.inf(1)
				rest:  s[body_start + 3..]
			}
		} else if word == 'nan' {
			// A NaN weighs as the largest negative finite number, which puts it
			// after the lines that have no number at all and before every number
			// there is. That is where GNU puts it, even though its manual lists
			// NaNs first.
			return NumberPrefix{
				value: -math.max_f64
				rest:  s[body_start + 3..]
			}
		}
	}

	body_end := scan_number_body(s, i, style)
	if body_end == body_start {
		// Nothing numeric at all. -g calls that minus infinity so that such lines
		// come first; -n and -h call it zero.
		return NumberPrefix{
			value: if style == .general { math.inf(-1) } else { 0.0 }
			rest:  s
		}
	}

	// The sign was stepped over above, so it is put back for the parser to read,
	// which is what keeps -5 negative rather than five.
	mut body := s[body_start..body_end]
	if negative {
		body = '-' + body
	}
	mut value := if style == .general {
		parse_general(body)
	} else {
		parse_plain(body)
	}

	// -h lets a size suffix follow the digits.
	mut end := body_end
	if style == .human {
		scale, suffix_len := size_suffix(s, end)
		if scale != 1.0 {
			value *= scale
			end += suffix_len
		}
	}

	return NumberPrefix{
		value: value
		rest:  s[end..]
	}
}

// scan_number_body returns where the numeric text ends, starting at i. It never
// runs past a character that is not part of a number.
fn scan_number_body(s string, i int, style NumberStyle) int {
	mut j := i
	mut seen_digit := false

	if style == .general && (s[j..].starts_with('0x') || s[j..].starts_with('0X')) {
		j += 2
		for j < s.len && is_hex_digit(s[j]) {
			j++
			seen_digit = true
		}
		return if seen_digit { j } else { i }
	}

	for j < s.len && s[j].is_digit() {
		j++
		seen_digit = true
	}
	// -n accepts a decimal point but no exponent, and -h the same.
	if j < s.len && s[j] == `.` && (style != .general || true) {
		mut k := j + 1
		mut frac := false
		for k < s.len && s[k].is_digit() {
			k++
			frac = true
		}
		if frac || seen_digit {
			j = k
			seen_digit = seen_digit || frac
		}
	}
	if !seen_digit {
		return i
	}
	// An exponent is read by -g in either case, and by -h only when it is written
	// with a capital E. GNU's own behaviour: -h weighs 1e3 as one, because the
	// lower case e stops the number, but weighs 1E3 as a thousand. -n reads no
	// exponent at all.
	if j < s.len && ((style == .general && (s[j] == `e` || s[j] == `E`))
		|| (style == .human && s[j] == `E`)) {
		mut k := j + 1
		if k < s.len && (s[k] == `-` || s[k] == `+`) {
			k++
		}
		mut exp_digits := false
		for k < s.len && s[k].is_digit() {
			k++
			exp_digits = true
		}
		if exp_digits {
			j = k
		}
	}
	return j
}

// size_suffix reads the multiplier that -h allows after the digits. The units up
// to T are accepted in either case, but P, E, Z and Y only in capitals: GNU weighs
// "1p" as one and "1P" as a petabyte, and the same for E, Z and Y. A lower case e
// is not a unit at all, which is why -h reads "1e3" as one.
//
// One combination is not modelled. GNU weighs a suffixed number against a plain
// one of seven digits or more by something this does not reproduce: it puts
// "1000000" before "1K", although every comparison of a suffix against a smaller
// plain number agrees, including 1K against 1024 and 2K against 1M. No value for
// the K in "1K" is consistent with both, since it has to be above 1e7 and at most
// 1024^4, which is what makes this look like a fault on GNU's side rather than a
// rule.
fn size_suffix(s string, i int) (f64, int) {
	if i >= s.len {
		return 1.0, 0
	}
	scale := match s[i] {
		`k`, `K` { f64(1024) }
		`m`, `M` { f64(1024) * 1024 }
		`g`, `G` { f64(1024) * 1024 * 1024 }
		`t`, `T` { f64(1024) * 1024 * 1024 * 1024 }
		`P` { f64(1024) * 1024 * 1024 * 1024 * 1024 }
		`E` { f64(1024) * 1024 * 1024 * 1024 * 1024 * 1024 }
		`Z` { f64(1024) * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 }
		`Y` { f64(1024) * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 }
		else { return 1.0, 0 }
	}
	mut used := 1
	// GNU also takes the optional i and B of 2KiB and 2KB, and so does this.
	if i + 1 < s.len && (s[i + 1] == `i` || s[i + 1] == `I`) {
		used++
		if i + 2 < s.len && (s[i + 2] == `B` || s[i + 2] == `b`) {
			used++
		}
	} else if i + 1 < s.len && (s[i + 1] == `B` || s[i + 1] == `b`) {
		used++
	}
	return scale, used
}

fn parse_plain(body string) f64 {
	return strconv.atof64(body) or { 0.0 }
}

// parse_general reads what -g accepts: an ordinary float, a hexadecimal float, or
// one of the words inf and nan, which C's strtod understands and V does not.
fn parse_general(body string) f64 {
	if body.len > 2 && (body.starts_with('inf') || body.starts_with('INF')) {
		return math.inf(1)
	}
	if body.len > 2 && (body.starts_with('nan') || body.starts_with('NAN')) {
		// A NaN weighs as the largest negative finite number, which puts it after
		// the lines that have no number at all and before every number there is.
		// That is where GNU puts it, even though its manual lists NaNs first.
		return -math.max_f64
	}
	if body.len > 2 && (body.starts_with('0x') || body.starts_with('0X')) {
		digits := body[2..]
		// A hexadecimal float may carry a fractional part after a point, which
		// strtof64 does not read, so it is scaled here.
		if point := digits.index('.') {
			int_part := digits[..point]
			frac_part := digits[point + 1..]
			mut value := f64(0.0)
			mut scale := 1.0
			for k in 0 .. int_part.len {
				value = value * 16.0 + f64(hex_value(int_part[k]))
			}
			for k in 0 .. frac_part.len {
				scale /= 16.0
				value += f64(hex_value(frac_part[k])) * scale
			}
			return value
		}
		// Plain hexadecimal without a fractional part.
		mut hex := u64(0)
		for c in digits {
			hex = hex * 16 + u64(hex_value(c))
		}
		return f64(hex)
	}
	return strconv.atof64(body) or { 0.0 }
}

fn hex_value(c u8) int {
	return match c {
		`0`...`9` { int(c - `0`) }
		`a`...`f` { int(c - `a`) + 10 }
		`A`...`F` { int(c - `A`) + 10 }
		else { 0 }
	}
}

fn is_hex_digit(c u8) bool {
	return c.is_digit() || (c >= `a` && c <= `f`) || (c >= `A` && c <= `F`)
}

fn is_blank(c u8) bool {
	return c == ` ` || c == `\t` || c == `\n` || c == `\v` || c == `\f` || c == `\r`
}
