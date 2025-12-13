import os
import arrays
import strconv

const space = ` `
const tab = `\t`

fn main() {
	options := get_options()
	results := sort(options)
	if options.output_file == '' {
		for result in results {
			println(result)
		}
	} else {
		os.write_lines(options.output_file, results) or { exit_error(err.msg()) }
	}
}

fn sort(options Options) []string {
	mut results := []string{}
	for file in options.files {
		results << do_sort(file, options)
	}
	return results
}

fn do_sort(file string, options Options) []string {
	mut lines := os.read_lines(file) or { exit_error(err.msg()) }
	original := if options.check_diagnose || options.check_quiet {
		lines.clone()
	} else {
		[]string{}
	}
	match true {
		// order matters here
		options.sort_keys.len > 0 { sort_key(mut lines, options) }
		options.numeric { sort_general_numeric(mut lines, options) }
		options.ignore_case { sort_ignore_case(mut lines, options) }
		options.dictionary_order { sort_dictionary_order(mut lines, options) }
		options.ignore_non_printing { sort_ignore_non_printing(mut lines, options) }
		options.ignore_leading_blanks { sort_ignore_leading_blanks(mut lines, options) }
		else { sort_lines(mut lines, options) }
	}
	if options.unique {
		lines = arrays.distinct(lines)
	}
	if original.len > 0 {
		if lines != original {
			if options.check_diagnose {
				println('sort: not sorted')
			}
			exit(1)
		} else {
			if options.check_diagnose {
				println('sort: already sorted')
			}
			exit(0)
		}
	}
	return lines
}

fn sort_lines(mut lines []string, options Options) {
	cmp := if options.reverse { compare_strings_reverse } else { compare_strings }
	lines.sort_with_compare(fn [cmp] (a &string, b &string) int {
		return cmp(a, b)
	})
}

fn compare_strings_reverse(a &string, b &string) int {
	return compare_strings(b, a)
}

fn sort_ignore_case(mut lines []string, options Options) {
	lines.sort_ignore_case()
	if options.reverse {
		lines.reverse_in_place()
	}
}

// Ignore leading blanks when finding sort keys in each line.
//  By default a blank is a space or a tab
fn sort_ignore_leading_blanks(mut lines []string, options Options) {
	cmp := if options.reverse { compare_strings_reverse } else { compare_strings }
	lines.sort_with_compare(fn [cmp] (a &string, b &string) int {
		return cmp(trim_leading_spaces(a), trim_leading_spaces(b))
	})
}

fn trim_leading_spaces(s string) string {
	return s.trim_left(' \n\t\v\f\r')
}

// Sort in phone directory order: ignore all characters except letters, digits
// and blanks when sorting. By default letters and digits are those of ASCII
fn sort_dictionary_order(mut lines []string, options Options) {
	cmp := if options.reverse { compare_strings_reverse } else { compare_strings }
	lines.sort_with_compare(fn [cmp] (a &string, b &string) int {
		aa := a.bytes().map(is_dictionary_char).bytestr()
		bb := b.bytes().map(is_dictionary_char).bytestr()
		return cmp(aa, bb)
	})
}

fn is_dictionary_char(e u8) u8 {
	return match e.is_digit() || e.is_letter() || e == space || e == tab {
		true { e }
		else { space }
	}
}

// Sort numerically, converting a prefix of each line to a long double-precision
// floating point number. See Floating point numbers. Do not report overflow,
// underflow, or conversion errors. Use the following collating sequence:
// Lines that do not start with numbers (all considered to be equal).
// - NaNs (“Not a Number” values, in IEEE floating point arithmetic) in a
//   consistent but machine-dependent order.
// - Minus infinity.
// - Finite numbers in ascending numeric order (with -0 and +0 equal).
// - Plus infinity
fn sort_general_numeric(mut lines []string, options Options) {
	cmp := if options.reverse { compare_strings_reverse } else { compare_strings }
	lines.sort_with_compare(fn [cmp, options] (a &string, b &string) int {
		numeric_a, rest_a := numeric_rest(a)
		numeric_b, rest_b := numeric_rest(b)
		numeric_diff := if options.reverse { numeric_b - numeric_a } else { numeric_a - numeric_b }
		return if numeric_diff != 0 {
			if numeric_diff > 0 { 1 } else { -1 }
		} else {
			cmp(rest_a, rest_b)
		}
	})
}

const minus_infinity = f64(-0xFFFFFFFFFFFFFFF)

fn numeric_rest(s string) (f64, string) {
	mut num := 0.0
	mut rest := s
	mut allow_blanks := true
	mut allow_sign := true
	for i := 0; i < s.len; i++ {
		c := s[i]
		if allow_blanks && c == space {
			continue
		}
		if allow_sign && (c == `-` || c == `+`) {
			allow_sign = false
			allow_blanks = false
			continue
		}
		if c.is_digit() || c == strconv.c_dpoint {
			allow_sign = false
			allow_blanks = false
			continue
		}
		num = strconv.atof64(s[0..i]) or { minus_infinity }
		rest = s[i..].clone()
	}
	return num, rest
}

// This option has no effect if the stronger --dictionary-order (-d) option
// is also given.
fn sort_ignore_non_printing(mut lines []string, options Options) {
	cmp := if options.reverse { compare_strings_reverse } else { compare_strings }
	lines.sort_with_compare(fn [cmp] (a &string, b &string) int {
		aa := a.bytes().map(is_printable).bytestr()
		bb := b.bytes().map(is_printable).bytestr()
		return cmp(aa, bb)
	})
}

fn is_printable(e u8) u8 {
	return if e >= u8(` `) && e <= u8(`~`) { e } else { space }
}
