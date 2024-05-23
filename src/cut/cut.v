// Cut - extract sections from each line of input
import common
import flag
import os

const app_name = 'cut'

struct Args {
	bytes     [2]int
	character [2]int
	file_args []string
}

fn main() {
	make_args()
}

fn cut(lines []string, arg Args) []string {
	return []string{}
}

fn make_args() Args {
	mut fp := common.flag_parser(os.args)
	eol := common.eol()
	wrap := eol + flag.space

	fp.application(app_name)
	fp.description('Print selected parts of lines from each FILE to standard output.${eol}')
	fp.description('With no FILE, or when FILE is -, read standard input.${eol}')

	fp.description('Use one, and only one of -b, -c or -f.  Each LIST is made up of one${eol}' +
		'range, or many ranges separated by commas.  Selected input is written${eol}' +
		'in the same order that it is read, and is written exactly once.${eol}${eol}' +
		'Each range is one of:${eol}${eol}' +
		'  N     N\'th byte, character or field, counted from 1${eol}' +
		'  N-    from N\'th byte, character or field, to end of line${eol}' +
		'  N-M   from N\'th to M\'th (included) byte, character or field${eol}' +
		'  -M    from first to M\'th (included) byte, character or field${eol}')

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

	file_args := fp.finalize() or { common.exit_with_error_message(app_name, err.msg()) }

	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('${app_name} ${common.coreutils_version()}')
	}

	// translate args

	return Args{
		bytes: get_range(bytes) or { common.exit_with_error_message(app_name, err.msg()) }
		file_args: file_args
	}
}

// range values interpreted as follows:
//  [s>=0, e>0]   simple range
//  [s>=0, e==-1] from s to end of string
//  [s>=0, e==0]  s'th byte only
fn get_range(arg string) ![2]int {
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
		return [start, 0]!
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
	return [start, end]!
}

@[noreturn]
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}
