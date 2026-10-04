module main

import common
import os

const app_name = 'join'

// join pairs up the lines of two files whose join field is equal, and writes the pairs
// with the fields the caller asks for.
//
// The measured rules that are not in the manual, all against GNU 9.4:
//
//   - The default separator is a run of blanks, or a single tab; -t replaces it with
//     exactly one character. That is why "-t :" over "a:1:x" and "a:5:p" pairs them
//     while the default does not, since the default sees one field in each line.
//   - Output lines are joined with the separator too, so -t : writes "a:1:x:5:p".
//   - A line with fewer fields than the join field takes no part in the pairing, but
//     -a 1 prints it anyway. Measured over a file holding "a 1", "b", "" and "c 3":
//     the default writes only the "a 1" pair, while -a 1 writes "b" and "" too.
//   - A bare number is not a field specifier. -o 1 is refused with "invalid field
//     specifier: ‘1’", so a file is always named: 0, 1.n, 2.n or e.
//   - -i compares without case but prints each file's own spelling, so "A 1" and
//     "a 5" pair and print as "A 1 5".
//   - The exit code is 1 only for a failure. Producing no output at all is a success,
//     and so is a join field that no line has, which then pairs everything with
//     everything: -j 9 over two four-line files writes sixteen lines.

// OutField is one entry of -o. file is 0 for the join field, 1 or 2 for a field of
// one file or the other, and 3 for the -e string.
struct OutField {
mut:
	file int
	n    int
}

struct Settings {
mut:
	file1       string = '-'
	file2       string = '-'
	field1      int    = 1
	field2      int    = 1
	separator   u8 // 0 means a run of blanks or a single tab
	ignore_case bool
	empty       string
	out         []OutField
	unpaired1   bool
	unpaired2   bool
	only1       bool
	only2       bool
}

fn main() {
	s := parse_args() or { join_error(err.msg()) }
	run(s) or { join_error(err.msg()) }
}

@[noreturn]
fn join_error(message string) {
	eprintln('${app_name}: ${message}')
	exit(1)
}

// advice_error is gone: every -o complaint measured against GNU 9.4 is printed on its
// own, with no advice line under it.

// parse_args reads the options through the shared parser.
//
// -a and -v are taken out of the argument list first, and -o1.2 is split into -o 1.2,
// because the parser cannot see either spelling.
fn parse_args() !Settings {
	kept, unpaired_values, only_values := extract_pair_flags(os.args)
	mut fp := common.flag_parser(kept)
	fp.application(app_name)
	fp.description('Relational database join.')

	field1 := fp.int('join-field', `1`, 0, 'join on field NUMBER of file 1')
	field2 := fp.int('join-field', `2`, 0, 'join on field NUMBER of file 2')
	both := fp.int('join-field', `j`, 0, 'join on field NUMBER of both files')
	separator := fp.string('separator', `t`, '',
		'use SEP instead of whitespace to separate input fields')
	ignore_case := fp.bool('ignore-case', `i`, false,
		'ignore case differences in the join field')
	empty := fp.string('empty', `e`, '', 'replace missing input fields with STRING')
	format := fp.string('output-format', `o`, 'auto',
		'use FORMAT to construct the output lines')

	mut set := Settings{
		ignore_case: ignore_case
		empty:       empty
	}
	if separator != '' {
		if separator.len > 1 {
			return error('multi-character tab ‘${separator}’')
		}
		set.separator = separator[0]
	}
	if both > 0 {
		if field1 > 0 || field2 > 0 {
			return error('incompatible join fields 0, 1')
		}
		set.field1 = both
		set.field2 = both
	} else {
		set.field1 = if field1 > 0 { field1 } else { 1 }
		set.field2 = if field2 > 0 { field2 } else { 1 }
	}
	// The argument names the file the unpaired lines come from, so -a 2 wants file 2
	// and -v 1 wants file 1. -v also drops the paired lines, which the pair loop reads
	// off only1 and only2. Every occurrence counts, since "-a1 -a2" prints both sides.
	for value in unpaired_values {
		if value == '1' {
			set.unpaired1 = true
		} else if value == '2' {
			set.unpaired2 = true
		} else {
			join_error('invalid field number: ‘${value}’')
		}
	}
	for value in only_values {
		if value == '1' {
			set.only1 = true
			set.unpaired1 = true
		} else if value == '2' {
			set.only2 = true
			set.unpaired2 = true
		} else {
			join_error('invalid field number: ‘${value}’')
		}
	}
	// The default of auto is how an absent -o is told apart from an explicit -o '', which
	// GNU refuses rather than reading as the default shape.
	if format != 'auto' {
		set.out = parse_format(format) or { join_error(err.msg()) }
	}

	mut files := fp.remaining_parameters()
	if files.len > 0 {
		set.file1 = files[0]
	}
	if files.len > 1 {
		set.file2 = files[1]
	}
	return set
}

// extract_pair_flags takes -a and -v out of the argument list and reports the file number
// each one names.
//
// They are read here rather than through the parser for two measured reasons. GNU lets
// both be given more than once and honours every one of them, while the parser keeps
// only the last value of a repeated option, so "-a1 -a2" would lose file 1. The parser
// also matches a short option only when the argument is exactly that character, so the
// glued "-a1" has to be split somewhere. GNU 9.4 has no long form of either option -
// "--unpaired" is refused as an unrecognized option - so there is no long spelling to
// recognise here.
//
// An option with no value after it takes the next word anyway, which is how "-a f1.txt"
// ends up complaining about the file name.
fn extract_pair_flags(args []string) ([]string, []string, []string) {
	mut kept := []string{cap: args.len + 2}
	mut unpaired := []string{}
	mut only := []string{}
	mut n := 0
	for n < args.len {
		arg := args[n]
		mut which := ''
		mut value := ''
		if arg == '-a' || arg == '-v' {
			which = arg[1..]
			n++
			if n < args.len {
				value = args[n]
			}
		} else if arg.len == 3 && arg[0] == `-` && (arg[1] == `a` || arg[1] == `v`)
			&& arg[2] >= `1` && arg[2] <= `2` {
			which = arg[1].ascii_str()
			value = arg[2].ascii_str()
		} else if arg.len > 2 && arg[0] == `-` && arg[1] == `o` {
			kept << '-o'
			kept << arg[2..]
			n++
			continue
		} else {
			kept << arg
			n++
			continue
		}
		if which == 'a' {
			unpaired << value
		} else {
			only << value
		}
		n++
	}
	return kept, unpaired, only
}

// parse_format reads an -o list. The wording of each complaint is measured.
fn parse_format(format string) ![]OutField {
	if format == '' {
		return error('invalid file number in field spec: ‘${format}’')
	}
	mut out := []OutField{}
	for part in format.split(',') {
		if part == '' {
			return error('invalid file number in field spec: ‘${format}’')
		}
		if part == '0' {
			out << OutField{}
			continue
		}
		if !part.contains('.') {
			// A bare number names a file but not a field, so "-o 1" and "-o 2" are refused
			// for leaving the field out. Anything else is not a file number at all, which is
			// the other complaint, and "e" is one of those: -e is the option that names the
			// empty string, and -o has no entry for it.
			n := part.int()
			if n == 1 || n == 2 {
				return error('invalid field specifier: ‘${part}’')
			}
			return error('invalid file number in field spec: ‘${part}’')
		}
		mut halves := part.split('.')
		if halves.len != 2 {
			return error('invalid field specifier: ‘${part}’')
		}
		file := halves[0].int()
		if file != 1 && file != 2 {
			return error('invalid file number in field spec: ‘${file}’')
		}
		if !all_digits(halves[1]) {
			return error('invalid field number: ‘${halves[1]}’')
		}
		out << OutField{
			file: file
			n:    halves[1].int()
		}
	}
	return out
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

// run pairs the two files and writes the result.
fn run(s Settings) ! {
	left := read_lines(s.file1) or { return err }
	right := read_lines(s.file2) or { return err }
	check_order(s, s.file1, left, s.field1) or { return err }
	check_order(s, s.file2, right, s.field2) or { return err }

	mut out := []u8{cap: 4096}
	mut i := 0
	mut j := 0
	// The merge only advances a side that has not run out, so the pairing is the same
	// linear walk a streaming join does over sorted input.
	for i < left.len && j < right.len {
		lkey := field(left[i], s.field1, s.separator)
		rkey := field(right[j], s.field2, s.separator)
		cmp := compare_keys(s, lkey, rkey)
		if cmp < 0 {
			if s.unpaired1 {
				append_line(mut out, unpaired(s, left[i], 1))
			}
			i++
			continue
		}
		if cmp > 0 {
			if s.unpaired2 {
				append_line(mut out, unpaired(s, right[j], 2))
			}
			j++
			continue
		}
		// Equal keys: pair every line on each side that carries the key, which is what
		// gives sixteen lines for -j 9 over two four-line files.
		mut i2 := i
		for i2 < left.len && compare_keys(s, field(left[i2], s.field1, s.separator), lkey) == 0 {
			i2++
		}
		mut j2 := j
		for j2 < right.len && compare_keys(s, field(right[j2], s.field2, s.separator), lkey) == 0 {
			j2++
		}
		for a in i .. i2 {
			for b in j .. j2 {
				if !s.only1 && !s.only2 {
					append_line(mut out, pair(s, left[a], right[b]))
				}
			}
		}
		i = i2
		j = j2
	}
	for i < left.len {
		if s.unpaired1 {
			append_line(mut out, unpaired(s, left[i], 1))
		}
		i++
	}
	for j < right.len {
		if s.unpaired2 {
			append_line(mut out, unpaired(s, right[j], 2))
		}
		j++
	}
	if out.len > 0 {
		write_stdout(out) or { return error(err.msg()) }
	}
}

// unpaired builds the line for an input that had no partner.
//
// The default shape of such a line is the line itself: the join field and the fields
// after it are what it already holds. Rebuilding it from field() and rest_of() instead
// loses a field whenever rest_of has to fall back to the whole line, and it forces the
// join character onto a line that was split on something else.
//
// An -o list is different, and does reshape the line: GNU prints "3" for
// "-v1 -o 1.2" on the line "b 3 z 7 r", not the line as it stands. The join field of a
// line with no partner is its own, and an entry naming the other file has nothing to draw
// from, so it falls back to the empty string the way a missing field does.
fn unpaired(s Settings, line string, file int) string {
	if s.out.len == 0 {
		// Under the default shape an unpaired line is written as it stands.
		return line
	}
	// An -o list does reshape it: GNU prints "3" for "-v1 -o 1.2" on the line
	// "b 3 z 7 r". The join field of a line with no partner is its own, and an entry that
	// names the other file has nothing to draw from, so it falls back to the empty string
	// the way a missing field does.
	own := if file == 1 { s.field1 } else { s.field2 }
	mut parts := []string{}
	for f in s.out {
		parts << match f.file {
			0 { missing(field(line, own, s.separator), s.empty) }
			file { missing(field(line, f.n, s.separator), s.empty) }
			else { s.empty }
		}
	}
	mut text := parts[0]
	for p in parts[1..] {
		text += join_char(s) + p
	}
	return text
}

// pair builds one output line.
//
// The default shape is the join field, then every field of each file except its own join
// field. A line with no join field to leave out contributes all of itself, which is what
// makes -j 9 print both whole lines behind an empty key.
//
// A field the line does not have is left out of the default shape entirely rather than
// written as empty, so pairing two one-field files writes "a" and not "a  ". An -o list
// is different: every entry it names is written even when the field is missing, which
// is why -o 1.9 writes five empty lines.
fn pair(s Settings, a string, b string) string {
	if s.out.len == 0 {
		// The join field is written even when it is empty, which is what leaves the leading
		// blank under -j 9, while a remainder with nothing in it is left out, which is what
		// keeps two one-field files printing "a" rather than "a  ".
		mut shape := field(a, s.field1, s.separator)
		r1 := rest_of(s, a, s.field1)
		if r1 != '' {
			shape += join_char(s) + r1
		}
		r2 := rest_of(s, b, s.field2)
		if r2 != '' {
			shape += join_char(s) + r2
		}
		return shape
	}
	mut parts := []string{}
	for f in s.out {
		parts << out_field(s, f, a, b)
	}
	mut line := parts[0]
	for p in parts[1..] {
		line += join_char(s) + p
	}
	return line
}

// rest_of is every field of the line except the join field, or the whole line when the
// line has no join field to leave out.
//
// It is not the fields *after* the join field. Measured over two three-field files whose
// second field matches, "join -j 2" writes "1 a x a z", so the fields in front of the
// join field are kept as well. And a ninth field that neither file has leaves the whole
// line, which is what makes -j 9 print both lines in full.
fn rest_of(s Settings, line string, join_field int) string {
	fs := fields(line, s.separator)
	if fs.len < join_field {
		return line
	}
	mut out := []string{}
	for n in 1 .. fs.len + 1 {
		if n != join_field {
			out << fs[n - 1]
		}
	}
	if out.len == 0 {
		return ''
	}
	mut text := out[0]
	for p in out[1..] {
		text += join_char(s) + p
	}
	return text
}

fn out_field(s Settings, f OutField, a string, b string) string {
	return match f.file {
		0 { field(a, s.field1, s.separator) }
		1 { missing(field(a, f.n, s.separator), s.empty) }
		2 { missing(field(b, f.n, s.separator), s.empty) }
		else { s.empty }
	}
}

fn join_char(s Settings) string {
	return if s.separator == 0 { ' ' } else { s.separator.ascii_str() }
}

// missing applies -e to a field the line does not have.
fn missing(got string, empty string) string {
	return if got == '' { empty } else { got }
}

fn compare_keys(s Settings, a string, b string) int {
	x := if s.ignore_case { a.to_lower() } else { a }
	y := if s.ignore_case { b.to_lower() } else { b }
	if x < y {
		return -1
	}
	if x > y {
		return 1
	}
	return 0
}

// append_line adds one output line, ending it with a newline when the caller did not
// supply one. An unpaired line that was empty in the input stays an empty line, which
// is what -a 1 prints for a blank line in the file.
fn append_line(mut out []u8, line string) {
	mut bytes := line.bytes()
	if bytes.len == 0 || bytes[bytes.len - 1] != 10 {
		bytes << 10
	}
	out << bytes
}

// check_order refuses input that is not sorted on its join field, which is the
// complaint measured for "-1 3" over an unsorted file.
//
// A line too short to hold the join field is left out of the comparison, because it
// takes no part in the pairing either. Measured over a file holding "a 1", "b", "" and
// "c 3", the default join is quiet, while reading the blank line as an empty first
// field would put it before the b and be called unsorted.
fn check_order(s Settings, name string, lines []string, field_no int) ! {
	mut previous := ''
	mut have := false
	for n, line in lines {
		if fields(line, s.separator).len < field_no {
			continue
		}
		key := field(line, field_no, s.separator)
		if have && compare_keys(s, key, previous) < 0 {
			return error('${name}:${n + 1}: is not sorted: ${line}' +
				'\n${app_name}: input is not in sorted order')
		}
		previous = key
		have = true
	}
}

// field returns the nth field of a line, or the empty string when the line is too
// short. A line with too few fields takes no part in the pairing, which is checked
// separately through paired().
fn field(line string, n int, sep u8) string {
	if n < 1 {
		return ''
	}
	fs := fields(line, sep)
	if n > fs.len {
		return ''
	}
	return fs[n - 1]
}

// fields splits a line. With -t each separator character stands alone, so an empty
// field is a real field and "a::x" has three. Without -t a run of blanks is one
// separator and leading and trailing blanks are not fields of their own.
fn fields(line string, sep u8) []string {
	if sep != 0 {
		mut out := []string{}
		mut cur := []u8{}
		for b in line.bytes() {
			if b == sep {
				out << cur.bytestr()
				cur = []u8{}
			} else {
				cur << b
			}
		}
		out << cur.bytestr()
		return out
	}
	mut out := []string{}
	mut cur := []u8{}
	mut have := false
	for b in line.bytes() {
		if b == ` ` || b == `\t` {
			if have {
				out << cur.bytestr()
				cur = []u8{}
				have = false
			}
			continue
		}
		cur << b
		have = true
	}
	if have {
		out << cur.bytestr()
	}
	return out
}

// write_stdout sends the collected bytes out. The output is written as bytes rather
// than through println, because a join line is taken from the input and may hold
// anything at all.
fn write_stdout(bytes []u8) ! {
	mut f := os.stdout()
	f.write(bytes)!
	f.flush()
}

fn read_lines(path string) ![]string {
	if path == '-' {
		return error('standard input is not usable here yet')
	}
	if !os.exists(path) {
		// os.error_posix hands back an IError, whose message still carries the
		// "; code: N" tail that GNU does not print.
		posix := os.error_posix()
		return error('${path}: ' + common.strip_error_code_from_msg(posix.msg()))
	}
	content := os.read_file(path) or { return error(err.msg()) }
	mut out := []string{}
	for line in content.split_into_lines() {
		out << line
	}
	return out
}
