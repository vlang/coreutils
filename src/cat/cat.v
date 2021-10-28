module main

import common
import os
import io

const (
	app_name        = 'cat'
	app_description = 'concatenate files and print on the standard output'
)

struct Settings {
	number_nonblanks bool // both number_nonblank, and number_all can never be true together
	number_all       bool
	squeeze_blank    bool
	show_ends        bool
	show_nonprinting bool
	show_tabs        bool
	unbuffered       bool
	fnames           []string
}

///===================================================================///
///                       Main Logic                                  ///
///===================================================================///

fn main() {
	cat(args())
}

fn cat(settings Settings) {
	mut fnames := settings.fnames

	// if there are no files, read from stdin
	if fnames.len < 1 {
		fnames = ['-']
	}

	for fname in fnames {
		mut file := os.File{}
		if fname == '-' {
			// handle stdin like Files
			file = os.stdin()
		} else {
			file = os.open(fname) or {
				eprintln('$app_name: $fname: No such file or directory')
				exit(1)
			}
		}

		mut br := io.new_buffered_reader(io.BufferedReaderConfig{ reader: file })
		// Instead of checking conditions for each line
		// a different path can be taken for different
		// options group for better 'performance'
		format_cond := settings.show_ends || settings.show_tabs || settings.show_nonprinting
		number_cond := settings.number_nonblanks || settings.number_all || settings.squeeze_blank

		match true {
			format_cond && number_cond { path_number_and_format(mut br, settings) }
			format_cond { path_format(mut br, settings) }
			number_cond { path_number(mut br, settings) }
			else { path_no_change(mut br, settings) }
		}
	}
}

///===================================================================///
///                       Different 'Paths'                           ///
///===================================================================///
fn path_no_change(mut br io.BufferedReader, _settings Settings) {
	mut stdout := os.stdout()
	io.cp(mut br, mut stdout) or {}
}

fn path_number(mut br io.BufferedReader, settings Settings) {
	mut last_line, mut line, mut line_number := '', '', 0
	for {
		line = br.read_line() or { break }
		line, last_line, line_number = number_lines(line, last_line, line_number, settings) or {
			continue
		}
		println(line)
	}
}

fn path_format(mut br io.BufferedReader, settings Settings) {
	mut line := ''
	for {
		line = br.read_line() or { break }
		line = format(line, settings)
		println(line)
	}
}

fn path_number_and_format(mut br io.BufferedReader, settings Settings) {
	mut last_line, mut line, mut line_number := '', '', 0
	for {
		line = br.read_line() or { break }
		line, last_line, line_number = number_lines(line, last_line, line_number, settings) or {
			continue
		}
		line = format(line, settings)
		println(line)
	}
}

///===================================================================///
///                       Helper Functions                           ///
///===================================================================///
// number , lines according to settings
// 'errors'  to signal that a line should be skipped
// Handles the following
// number_nonblanks bool
// number_all       bool
// squeeze_blank    bool
fn number_lines(line string, last_line string, line_number int, settings Settings) ?(string, string, int) {
	// number_all has overrides number_nonblanks.
	if settings.squeeze_blank && line == '' && last_line == '' {
		return error('skip line')
	}
	if settings.number_nonblanks && line != '' {
		return ' $line_number\t$line', line, line_number + 1
	}
	if settings.number_all {
		return ' $line_number\t$line', line, line_number + 1
	}
	// no numbering, shouldn't happen since this path is always be numbered
	return line, line, line_number
}

// format , formats a line according to the settings,
// handles the following settings
// show_ends        bool
// show_nonprinting bool
// show_tabs        bool
fn format(content string, settings Settings) string {
	mut line := content
	if settings.show_ends {
		line += '$'
	}
	if settings.show_nonprinting {
		// TODO!
	}
	if settings.show_tabs {
		line = line.replace('\t', '^I')
	}
	return line
}

///===================================================================///
///                                Args                               ///
///===================================================================///
fn args() Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	show_all := fp.bool('show-all', `A`, false, 'equivalent to -vET')
	number_nonblanks := fp.bool('number-nonblank', `b`, false, "Number the lines, but don't count blank lines, override -n")
	show_ends_and_v := fp.bool('', `e`, false, 'equivalent to -vE')
	mut show_ends := fp.bool('show-ends', `E`, false, 'display $ at end of each line')
	mut number_all := fp.bool('number', `n`, false, 'Number the output lines, starting at 1.')
	squeeze_blank := fp.bool('sqeeze-blank', `s`, false, 'Squeeze multiple adjacent empty lines, causing the output to be single spaced')
	mut show_tabs := fp.bool('', `t`, false, 'Print tab characters as ‘^I’. Implies the -v option to display non-printing characters')
	show_tabs_and_v := fp.bool('', `T`, false, 'equivalent to -vT')
	// unbuffered        := fp.bool('', `u`, false, 'The output is guaranteed to be unbuffered')
	unbuffered := fp.bool('', `u`, false, '(ignored)') // ignored in GNU cat!
	mut show_nonprinting := fp.bool('show-nonprinting', `v`, false, 'use ^ and M- notation, except for LFD and TAB')

	fnames := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		exit(1)
	}

	// some flags override each other
	show_ends = show_ends || show_ends_and_v || show_all
	show_tabs = show_tabs || show_tabs_and_v || show_all
	show_nonprinting = show_nonprinting || show_ends_and_v || show_all || show_tabs_and_v
	number_all = number_all && !number_nonblanks

	return Settings{number_nonblanks, number_all, squeeze_blank, show_ends, show_nonprinting
		|| show_ends_and_v, show_tabs, unbuffered, fnames}
}
