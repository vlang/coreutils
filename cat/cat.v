module main

import flag
import os
import io

const (
	app_name        = 'cat'
	app_version     = 'v0.0.1'
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

fn cat(settings Settings) {
	mut fnames := settings.fnames

	// if there are no files, read from stdin
	if fnames.len < 1 {
		fnames = ['-']
	}

	for fname in fnames {
		if fname == '-' {
			// mut content := os.get_lines()
			//// formatted := format(content[0], settings) or { continue }
			// println(formatted)
		} else {
			file := os.open(fname) or {
				eprintln('$fname couldn\'t be opened')
				exit(1)
			}
			match true {
				true { dump_lines(file, settings) }
				false {}
			}
		}
	}
}

fn dump_lines(file os.File, settings Settings) {
	mut last_line, mut line, mut line_number := '', '', 0
	mut br := io.new_buffered_reader(io.BufferedReaderConfig{ reader: file })
	for {
		line = br.read_line() or { break }
		line, last_line, line_number = number_lines(line, last_line, line_number, settings) or {
			continue
		}
		line = format(line, settings)
		println(line)
	}
}

// number , lines according to settings
// handles showing numbering and squeezing blank lins
// 'errors'  to signal that a line should be skipped
fn number_lines(line string, last_line string, line_number int, settings Settings) ?(string, string, int) {
	if settings.squeeze_blank && line == '' && last_line == '' {
		return error('skip line')
	}
	if settings.number_nonblanks && line != '' {
		return ' $line_number\t$line', line, line_number + 1 // TODO DOCS!
	}
	if settings.number_all {
		return ' $line_number\t$line', line, line_number + 1
	}
	// Should never happen, making compiler happy
	return line, line, line_number + 1
}

// format , formats a line according to the settings,
// handles showing non-printing characters
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

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application(app_name)
	fp.version(app_version)
	fp.description(app_description)
	fp.skip_executable()

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
	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')

	fnames := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		exit(1)
	}

	if help {
		println(fp.usage())
		exit(0)
	}
	if version {
		println('$app_name $app_version')
		exit(0)
	}

	// some flags override each other
	show_ends = show_ends || show_ends_and_v || show_all
	show_tabs = show_tabs || show_tabs_and_v || show_all
	show_nonprinting = show_nonprinting || show_ends_and_v || show_all || show_tabs_and_v
	number_all = number_all && !number_nonblanks

	cat(Settings{number_nonblanks, number_all, squeeze_blank, show_ends, show_nonprinting
		|| show_ends_and_v, show_tabs, unbuffered, fnames})
}
