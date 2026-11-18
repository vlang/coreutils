import common
import os

const app_name = 'paste'

struct Options {
	serial          bool
	next_delimiter  fn (bool) string = next_delimiter('\t')
	zero_terminated bool
	files           []string
}

fn get_options() Options {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.arguments_description('[FILES]')
	fp.description('\nWrite lines consisting of the sequentially corresponding lines from' +
		'\neach FILE, separated by TABs, to standard output.' +
		'\n\nWith no FILE, or when FILE is -, read standard input.')

	delimiters := fp.string('delimiters', `d`, '\t', 'reuse characters from LIST instead of TABs')
	serial := fp.bool('serial', `s`, false, 'paste one file at a time instead of in parallel')
	zero_terminated := fp.bool('zero-terminated', `z`, false,
		'line delimiter is NUL, not newline\n')

	files := fp.finalize() or { exit_error(err.msg()) }

	return Options{
		serial:          serial
		next_delimiter:  next_delimiter(delimiters)
		zero_terminated: zero_terminated
		files:           files
	}
}

fn next_delimiter(delimiters string) fn (bool) string {
	mut idx := 0
	sd := delimiters.runes()
	return fn [mut idx, sd] (reset bool) string {
		if reset {
			idx = 0
			return ''
		}
		delimiter := sd[idx]
		idx += (idx + 1) % sd.len
		return delimiter.str()
	}
}

@[noreturn]
fn exit_error(msg string) {
	common.exit_with_error_message(app_name, msg)
}
