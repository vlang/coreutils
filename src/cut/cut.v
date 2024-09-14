// Cut - extract sections from each line of input
import arrays
import common
import flag
import io
import os
import v.mathutil

const app_name = 'cut'
const space_comma = ' ,'

struct Args {
	byte_range_list  []Range
	char_range_list  []Range
	field_range_list []Range
	delimiter        rune = `\t`
	only_delimited   bool
	zero_terminated  bool
	complement       bool
	output_delimiter string = '\t'
	file_list        []string
}

// range values interpreted as follows:
//  [s>=1, e>=1]  simple range
//  [s>=1, e==-1] from s to end of string
struct Range {
	start int
	end   int
}

fn main() {
	args := get_args(os.args)
	validate_args(args) or { exit_error(err.msg()) }

	for file in args.file_list {
		lines := if args.zero_terminated {
			read_all_lines_zero_terminated(file)
		} else {
			read_all_lines(file)
		}

		cut_lines(lines, args, fn (s string) {
			println(s)
		})
	}
}

fn cut_lines(lines []string, args Args, out_fn fn (s string)) {
	for line in lines {
		match true {
			line.len == 0 { out_fn('') }
			args.byte_range_list.len > 0 { cut_bytes(line, args, out_fn) }
			args.char_range_list.len > 0 { cut_chars(line, args, out_fn) }
			args.field_range_list.len > 0 { cut_fields(line, args, out_fn) }
			else { exit_error('Invalid internal state') } // should never get here
		}
	}
}

fn cut_bytes(line string, args Args, out_fn fn (s string)) {
	ranges := combine_ranges_and_zero_index(args.byte_range_list, line.len, args.complement)
	mut output := ''
	for range in ranges {
		output += if range.start <= line.len { line.substr(range.start, range.end) } else { '' }
	}
	out_fn(output)
}

// Like cut_bytes() but handles unicode
fn cut_chars(line string, args Args, out_fn fn (s string)) {
	chars := line.runes()
	ranges := combine_ranges_and_zero_index(args.char_range_list, chars.len, args.complement)
	mut output := ''

	for range in ranges {
		output += if range.start <= line.len { chars[range.start..range.end].string() } else { '' }
	}

	out_fn(output)
}

fn cut_fields(line string, args Args, out_fn fn (s string)) {
	mut runes := [][]rune{}
	fields := get_fields(line.runes(), args.delimiter)

	if fields.len == 0 {
		if !args.only_delimited {
			out_fn(line)
		}
		return
	}

	ranges := combine_ranges_and_zero_index(args.field_range_list, fields.len, args.complement)

	for range in ranges {
		runes << if range.start <= fields.len { fields[range.start..range.end] } else { [][]rune{} }
	}

	output := arrays.join_to_string[[]rune](runes, args.output_delimiter, fn (c []rune) string {
		return c.string()
	})

	out_fn(output)
}

// Combines ranges where they overlap, ordered low to high
//
// CUT unintuitively combines overlapping ranges. Not sure
// what the use case here. Seems like it would be more
// useful to treat each range indepentently and append to
// the results to the output. Documentation does not
// comment on how or why overlapping ranges are combined.
//
// Example:
//   echo "Now is the time" | cut -b 1-3,1-6
//
//   returns "Now is". I expected "NowNow is"
//
// Furthermore, the order of ranges is not considered.
// Again, it appears CUT reorders ranges from low to high.
fn combine_ranges_and_zero_index(ranges []Range, max int, complement bool) []Range {
	mut combined_ranges := []Range{}

	outer: for range in ranges.sorted(a.start < b.start) {
		start := range.start - 1
		end := if range.end == -1 { max } else { mathutil.min(max, range.end) }

		for mut combined_range in combined_ranges {
			if range_overlaps_range(start, end, combined_range.start, combined_range.end) {
				combined_range = Range{
					start: mathutil.min(start, combined_range.start)
					end:   mathutil.max(end, combined_range.end)
				}
				continue outer
			}
		}

		combined_ranges << Range{start, end}
	}

	if complement {
		combined_ranges = arrays.flatten[Range](combined_ranges.map(complement_range(it,
			max)))
	}

	return combined_ranges
}

fn range_overlaps_range(start1 int, end1 int, start2 int, end2 int) bool {
	return (start1 >= start2 && start1 <= end2) || (end1 >= start2 && end1 <= end2)
}

fn get_fields(chars []rune, delimiter rune) [][]rune {
	mut field := []rune{}
	mut fields := [][]rune{}

	if !chars.contains(delimiter) {
		return fields
	}

	for c in chars {
		if c != delimiter {
			field << c
		} else {
			fields << field
			field = []rune{}
		}
	}

	if field.len > 0 {
		fields << field
	}

	return fields
}

fn get_args(args []string) Args {
	mut fp := flag.new_flag_parser(args)
	eol := common.eol()
	wrap := eol + flag.space

	fp.application(app_name)
	fp.version(common.coreutils_version())
	fp.skip_executable()
	fp.description('Print selected parts of lines from each FILE to standard output.')

	bytes := fp.string('bytes', `b`, '', 'select only <string> range of bytes')
	characters := fp.string('characters', `c`, '', 'select only <string> range of characters')
	delimiter := fp.string('delimter', `d`, '', 'use <string> instead of TAB for field delimter')
	fields := fp.string('fields', `f`, '',
		'select only <string> fields; also print any line${wrap}' +
		'that contains no delimiter character, unless the${wrap}-s option is specified')
	fp.bool('', `n`, false, '(ignored)')
	complement := fp.bool('complement', ` `, false, 'complement the set of selected bytes, characters${wrap}or fields')
	output_delimiter := fp.string('output-delimiter', ` `, '', 'use <string> as the output delimiter, default is${wrap}input delimiter')
	only_delimited := fp.bool('only-delimited', `s`, false, 'print only lines containing delimiters')
	zero_terminated := fp.bool('zero-terminated', `z`, false, 'line delimiter is NUL, not newline')

	help := fp.bool('help', 0, false, 'display this help')
	version := fp.bool('version', 0, false, 'output version information')

	fp.footer('${eol}With no FILE, or when FILE is -, read standard input.${eol}${eol}' +
		'Use one, and only one of -b, -c or -f.  Each LIST is made up of one${eol}' +
		'range, or many ranges separated by commas. Selected input is written${eol}' +
		'in the same order that it is read, and is written exactly once.${eol}${eol}' +
		'Each range is one of:${eol}${eol}' +
		'  N     N\'th byte, character or field, counted from 1${eol}' +
		'  N-    from N\'th byte, character or field, to end of line${eol}' +
		'  N-M   from N\'th to M\'th (included) byte, character or field${eol}' +
		"  -M    from first to M'th (included) byte, character or field")
	fp.footer(common.coreutils_footer())

	file_args := fp.finalize() or { exit_error(err.msg()) }
	file_list := if file_args.len > 0 { file_args } else { ['-'] }

	if help {
		exit_success(fp.usage())
	}

	if version {
		exit_success('${app_name} ${common.coreutils_version()}')
	}

	// translate range arguments
	byte_range_list := get_ranges(bytes) or { exit_error(err.msg()) }
	char_range_list := get_ranges(characters) or { exit_error(err.msg()) }
	field_list := get_ranges(fields) or { exit_error(err.msg()) }

	// delimiter handling is messy. If specified, it must be a
	// single character and only valid when operating on fields
	if delimiter.len > 1 {
		exit_error('delimiter must be a single character')
	}

	if delimiter.len == 1 && fields.len == 0 {
		exit_error('input delimiter may be specified only when operating on fields')
	}

	input_delim := if delimiter.len != 0 { delimiter.runes()[0] } else { 0 }
	output_delim := if output_delimiter.len == 0 { delimiter } else { output_delimiter }

	return Args{
		byte_range_list:  byte_range_list
		char_range_list:  char_range_list
		field_range_list: field_list
		delimiter:        input_delim
		only_delimited:   only_delimited
		zero_terminated:  zero_terminated
		complement:       complement
		output_delimiter: output_delim
		file_list:        file_list
	}
}

fn get_ranges(arg string) ![]Range {
	args := arg.split_any(space_comma).filter(it.len > 0)
	mut ranges := []Range{}
	for ar in args {
		ranges << get_range(ar)!
	}
	return ranges
}

fn get_range(arg string) !Range {
	mut idx := 0
	mut s := ''
	mut e := ''
	err_msg := 'invalid range syntax (--help for more info)'

	for idx < arg.len && arg[idx].is_digit() {
		s += arg[idx].ascii_str()
		idx += 1
	}

	start := if s.len > 0 { s.int() } else { 1 }
	if start < 1 {
		return error('start of range less than 1')
	}

	if idx == arg.len {
		return Range{start, start}
	}

	if arg[idx] != `-` {
		return error(err_msg)
	}

	idx += 1

	for idx < arg.len && arg[idx].is_digit() {
		e += arg[idx].ascii_str()
		idx += 1
	}

	if idx != arg.len {
		return error(err_msg)
	}

	end := if e.len > 0 { e.int() } else { -1 }
	return Range{start, end}
}

// Range is zero indexed
fn complement_range(range Range, max int) []Range {
	mut ranges := []Range{}
	if range.start > 0 {
		ranges << Range{0, range.start}
	}
	if range.end < max {
		ranges << Range{range.end, max}
	}
	return ranges
}

fn validate_args(args Args) ! {
	has_byte_range_list := if args.byte_range_list.len > 0 { 1 } else { 0 }
	has_char_range_list := if args.char_range_list.len > 0 { 1 } else { 0 }
	has_fields := if args.field_range_list.len > 0 { 1 } else { 0 }
	count := has_byte_range_list + has_char_range_list + has_fields

	if count == 0 {
		return error('must specify one, and only one of -b, -c, or -f')
	}
}

fn read_all_lines(file string) []string {
	return if file == '-' {
		mut br := io.new_buffered_reader(io.BufferedReaderConfig{ reader: os.stdin() })
		buffered_read_lines(mut br)
	} else {
		os.read_lines(file) or { exit_error(err.msg()) }
	}
}

fn read_all_lines_zero_terminated(file string) []string {
	if file == '-' {
		exit_error('--zero-terminated with stdin not supported')
	}

	bytes := os.read_bytes(file) or { exit_error(err.msg()) }
	return read_lines_zero_terminated(bytes)
}

fn read_lines_zero_terminated(bytes []u8) []string {
	mut lines := []string{}
	mut start := 0
	mut index := 0
	for b in bytes {
		index += 1
		if b == 0 {
			lines << bytes[start..index - 1].bytestr()
			start = index
		}
	}

	if start != index {
		lines << bytes[start..index].bytestr()
	}

	return lines
}

fn buffered_read_lines(mut br io.BufferedReader) []string {
	mut lines := []string{}
	for {
		lines << br.read_line() or { break }
	}
	return lines
}

@[noreturn]
fn exit_success(msg string) {
	println(msg)
	exit(0)
}

@[noreturn]
fn exit_error(msg string) {
	common.exit_with_error_message(app_name, msg)
}
