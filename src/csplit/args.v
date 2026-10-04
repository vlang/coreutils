module main

import common
import os

// quoted wraps an operand the way GNU does. The quotes are U+2018 and U+2019, and
// a backslash inside them is doubled: the operand /a\bb/ is reported as ‘/a\\bb/’,
// which is checked by counting bytes rather than by reading it.
fn quoted(text string) string {
	return quote_left + text.replace('\\', '\\\\') + quote_right
}

// parse_args turns the operand list into patterns, in the order GNU classifies them:
// while it walks the arguments. That is why a bad pattern is reported before a file
// that cannot be opened, and why "ten.txt /3/ nosuch" complains about "nosuch" being
// an invalid pattern rather than about a second operand.
fn parse_args() !Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('Split a file into pieces separated by pattern lines.')

	// A repeated -f or -b takes the last one, which is measured: "-f xx -f yy" names
	// its pieces yy00 and yy01. The flag module keeps the first, so these are read as
	// multi-values and the last is taken here.
	prefixes := fp.string_multi('prefix', `f`, 'use PREFIX instead of ‘xx’')
	suffixes := fp.string_multi('suffix-format', `b`, 'use sprintf FORMAT instead of %02d')
	digits_text := fp.string('digits', `n`, default_digits.str(),
		'use specified number of digits instead of 2')
	keep_files := fp.bool('keep-files', `k`, false, 'do not remove output files on errors')
	suppress := fp.bool('suppress-matched', 0, false, 'suppress the lines matching PATTERN')
	silent := fp.bool('quiet', `s`, false, 'do not print counts of output file sizes')
	elide := fp.bool('elide-empty-files', `z`, false, 'suppress empty output files')

	rest := fp.remaining_parameters()
	if rest.len < 2 {
		// GNU names the operand it ran out of patterns after, and unlike a complaint
		// about a pattern it is the only one that does not arrive through the shared
		// helper, because that helper adds a "Try --help" line csplit never prints.
		last := if rest.len > 0 { rest[rest.len - 1] } else { '' }
		// This one complaint does carry the advice line, which is the other half of
		// why it is not routed through the shared helper: the helper would add that
		// line to every operand complaint, and csplit prints it only for this one.
		operand_error("missing operand after ${quoted(last)}\nTry '${app_name} --help' for more information.")
	}
	mut set := Settings{
		file:        rest[0]
		prefix:      default_prefix
		suffix:      ''
		keep_files:  keep_files
		suppress:    suppress
		silent:      silent
		elide_empty: elide
	}
	if prefixes.len > 0 {
		set.prefix = prefixes[prefixes.len - 1]
	}
	if suffixes.len > 0 {
		set.suffix = suffixes[suffixes.len - 1]
	}
	set.digits = parse_digits(digits_text)!
	for arg in rest[1..] {
		set.patterns << parse_pattern(arg)!
	}
	return set
}

// check_repetitions refuses a {INTEGER} or {*} that has no plain pattern in front of
// it, or that follows another repetition.
//
// This runs after the input has been opened rather than with the rest of the
// arguments, which is measured: given a first operand of "3" and a pattern of "{1}",
// GNU complains that it cannot open "3" and never mentions the repetition. The check
// is still before anything is written, so "/3/ {2} {2}" over ten lines prints nothing
// at all, where a check during the run would already have printed 4 and 17.
fn check_repetitions(pats []Pat) {
	mut have_plain := false
	mut repeats := false
	for p in pats {
		if p.kind != .repeat {
			have_plain = true
			repeats = false
			continue
		}
		if !have_plain || repeats {
			operand_error(quoted(p.text) + ': invalid pattern')
		}
		repeats = true
	}
}

// operand_error reports a complaint about an operand. It prints the message on its
// own rather than through common.exit_with_error_message, because that helper adds a
// "Try 'csplit --help' for more information." line that csplit does not print for
// anything it says about its operands.
@[noreturn]
fn operand_error(message string) {
	eprintln('${app_name}: ${message}')
	exit(1)
}

// parse_digits reads -n. GNU takes 0 and refuses a negative one, and says so in its
// own words, which is why this is not left to the flag module's integer reader.
fn parse_digits(text string) !int {
	mut value := 0
	mut seen := false
	for b in text {
		if b < `0` || b > `9` {
			// A leading minus is the one non-digit GNU names separately.
			if text.len > 1 && text[0] == `-` && all_digits(text[1..]) {
				return error('invalid number: ‘${text}’: Numerical result out of range')
			}
			return error('invalid number: ‘${text}’')
		}
		value = value * 10 + int(b - `0`)
		seen = true
	}
	if !seen {
		return error('invalid number: ‘${text}’')
	}
	return value
}

fn all_digits(s string) bool {
	if s.len == 0 {
		return false
	}
	for b in s {
		if b < `0` || b > `9` {
			return false
		}
	}
	return true
}

// parse_pattern classifies one PATTERN operand. The delimiter is found at the first
// occurrence of its own character and is not itself escapable, which is measured:
// "/b\/" is the pattern "b\" followed by nothing, and csplit refuses it as a trailing
// backslash rather than reading the slash as part of the pattern.
fn parse_pattern(arg string) !Pat {
	if arg.len > 0 && arg[0] == `/` {
		return parse_delimited(arg, `/`, .regex)
	}
	if arg.len > 0 && arg[0] == `%` {
		return parse_delimited(arg, `%`, .skip)
	}
	if arg.len > 2 && arg[0] == `{` && arg[arg.len - 1] == `}` {
		inner := arg[1..arg.len - 1]
		if inner == '*' {
			return Pat{
				kind:   .repeat
				text:   arg
				number: -1
			}
		}
		if all_digits(inner) {
			return Pat{
				kind:   .repeat
				text:   arg
				number: inner.int()
			}
		}
		return error(quoted(arg) + ': invalid pattern')
	}
	if arg.len > 0 && (arg[0] == `+` || (arg[0] >= `0` && arg[0] <= `9`)) {
		// "+3" is accepted and means 3. A bare 0 is refused by name rather than
		// being taken for the start of the file.
		body := if arg[0] == `+` { arg[1..] } else { arg }
		if all_digits(body) {
			number := body.int()
			if number == 0 {
				// The operand is echoed as it was written, so "+0" is named rather
				// than the 0 it stands for.
				return error('${arg}: line number must be greater than zero')
			}
			return Pat{
				kind:   .line_number
				text:   arg
				number: number
			}
		}
	}
	return error(quoted(arg) + ': invalid pattern')
}

// parse_delimited reads a /REGEXP/[OFFSET] or %REGEXP%[OFFSET] operand.
fn parse_delimited(arg string, delim u8, kind PatKind) !Pat {
	mut close := -1
	for i in 1 .. arg.len {
		if arg[i] == delim {
			close = i
			break
		}
	}
	if close < 0 {
		// The complaint names the delimiter that was opened, with plain quotes, and
		// the operand outside any: "/8%: closing delimiter '/' missing".
		return error("${arg}: closing delimiter '${delim.ascii_str()}' missing")
	}
	source := arg[1..close]
	rest := arg[close + 1..]
	mut offset := 0
	if rest.len > 0 {
		offset = parse_offset(arg, rest) or { return err }
	}
	return Pat{
		kind:   kind
		text:   arg
		re:     source
		offset: offset
	}
}

// parse_offset reads the number after the closing delimiter. It is optional, but
// anything there has to be a number: "/b/ " is refused where "/b/" is not.
fn parse_offset(arg string, rest string) !int {
	mut negative := false
	mut body := rest
	if rest[0] == `+` || rest[0] == `-` {
		negative = rest[0] == `-`
		body = rest[1..]
	}
	if !all_digits(body) {
		return error(quoted(arg) + ': integer expected after delimiter')
	}
	return if negative { -body.int() } else { body.int() }
}

// read_input reads the whole operand up front. csplit reports the size of every piece
// in bytes and cuts at line boundaries, so there is no streaming case to keep.
fn read_input(path string) ![]u8 {
	if path == '-' {
		mut out := []u8{}
		for {
			line := os.get_raw_line()
			if line.len == 0 {
				break
			}
			out << line.bytes()
		}
		return out
	}
	if !os.exists(path) {
		return error("cannot open '${path}' for reading: No such file or directory")
	}
	return os.read_bytes(path)!
}
