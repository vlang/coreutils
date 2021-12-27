module main

import common
import arrays
import os

const (
	app_name        = 'tac'
	app_description = 'concatenate files and print lines reversed by characters on the standard output'
	page_size       = 4096
)

struct Settings {
	separator    string
	before       bool
	sep_as_regex bool
}

fn print_help() {
	println('Usage: tac [OPTION]... [FILE]...')
	println('Write each FILE to standard output, last line first.')
	println('')
	println('With no FILE, or when FILE is -, read standard input.')
	println('')
	println('Mandatory arguments to long options are mandatory for short options too.')
	println('  -b, --before             attach the separator before instead of after')
	println('  -r, --regex              interpret the separator as a regular expression')
	println('  -s, --separator=STRING   use STRING as the separator instead of newline')
	println('  -h  --help     display this help and exit')
	println('  -v  --version  output version information and exit')
}

fn print_version() {
	println('v0.0.1')
}

fn args() ([]string, Settings) {
	mut fp := common.flag_parser(os.args)

	fp.application(app_name)
	fp.description(app_description)

	separator := fp.string('separator', `s`, '\n', 'Separator to use')
	before := fp.bool('before', `b`, false, '')
	help := fp.bool('help', `h`, false, 'Print help text and exit')
	sep_as_regex := fp.bool('sep-as-regex', `r`, false, 'Treat separator as regex')
	version := fp.bool('version', `v`, false, 'output version information and exit')

	if help || os.args.len == 0 {
		print_help()
		exit(0)
	}

	if version {
		print_version()
		exit(0)
	}

	return fp.args, Settings{separator, before, sep_as_regex}
}

fn reverse_file_content(file os.File, settings Settings) {
	mut lines := [][]byte{}
	mut idx := 0

	for {
		b := file.read_bytes_at(page_size, u64(page_size * idx))

		if b.len == 0 {
			break
		}

		idx += 1
		lines << b
	}

	full_text := arrays.flatten(lines).bytestr()
	full_lines := full_text.split(settings.separator).reverse()

	for index, line in full_lines {
		if settings.before {
			if index < full_lines.len - 1 {
				print(settings.separator)
			}
			print(line)
		} else {
			print(line)
			if index > 0 {
				print(settings.separator)
			}
		}
	}
}

fn tac(files []string, settings Settings) {
	if files.len == 0 {
		mut file := os.stdin()
		reverse_file_content(file, settings)
		file.close()
	} else {
		for filename in files {
			if !os.is_file(filename) {
				eprintln('Error - Not a file $filename')
				exit(-1)
			}

			mut file := os.open(filename) or {
				eprintln('Error - Could not open file $filename')
				exit(-1)
			}

			reverse_file_content(file, settings)
			file.close()
		}
	}
}

fn main() {
	files, settings := args()
	tac(files, settings)
}
