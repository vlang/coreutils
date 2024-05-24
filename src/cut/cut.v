// Cut - extract sections from each line of input
import common
import flag
import io
import os

const app_name = 'cut'
const space_comma = ' ,'

struct Args {
	byte_range_list  []Range
	char_range_list  []Range
	fields_list      []string
	delimiter        string
	only_delimited   bool
	zero_terminated  bool
	complement       string
	output_delimiter string
	file_args        []string
}

// range values interpreted as follows:
//  [s>=0, e>0]   simple range
//  [s>=0, e==-1] from s to end of string
//  [s>=0, e==0]  s'th byte only
struct Range {
	start int
	end   int
}

fn main() {
	args := get_args(os.args)
	validate_args(args) or { exit_error(err.msg()) }

	for file in args.file_args {
		lines := read_all_lines(file)
		cut(lines, args)
	}
}

fn cut(lines []string, arg Args) []string {
	return []string{}
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
	only_delimited := fp.bool('only-delimited', `s`, false, 'do not print lines not containing delimiters')
	zero_terminated := fp.bool('zero-terminated', `z`, false, 'line delimiter is NUL, not newline')
	complement := fp.string('complement', ` `, '', 'complement the set of selected bytes, characters${wrap}or fields')
	output_delimiter := fp.string('output-delimiter', ` `, '', 'use <string> as the output delimiter, default is${wrap}input delimiter')

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

	if help {
		exit_success(fp.usage())
	}
	if version {
		exit_success('${app_name} ${common.coreutils_version()}')
	}

	// translate range arguments
	byte_range_list := get_ranges(bytes) or { exit_error(err.msg()) }
	char_range_list := get_ranges(characters) or { exit_error(err.msg()) }
	fields_list := fields.split_any(space_comma).filter(it.len > 0)

	return Args{
		byte_range_list: byte_range_list
		char_range_list: char_range_list
		fields_list: fields_list
		delimiter: delimiter
		only_delimited: only_delimited
		zero_terminated: zero_terminated
		complement: complement
		output_delimiter: output_delimiter
		file_args: file_args
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

	start := if s.len > 0 { s.int() } else { 0 }

	if idx == arg.len && start != -1 {
		return Range{start, 0}
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

fn validate_args(args Args) ! {
	mut has_byte_range_list := false
	mut has_char_range_list := false
	mut has_fields := false

	if !has_byte_range_list && !has_char_range_list && !has_fields {
		return error('must specify a list of bytes, characters, or fields')
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

fn buffered_read_lines(mut br io.BufferedReader) []string {
	mut lines := []string{}
	for {
		lines << br.read_line() or { break }
	}
	return lines
}

@[noreturn]
fn exit_success(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}

@[noreturn]
fn exit_error(msg string) {
	common.exit_with_error_message(app_name, msg)
}
