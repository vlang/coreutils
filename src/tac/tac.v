module main

import common
import arrays
import os

const (
	app_name        = 'tac'
	app_description = 'Write each FILE to standard output, last line first.\n' +
					  'With no FILE, or when FILE is -, read standard input.'
	page_size       = 4096
)

struct Settings {
	separator    string
	before       bool
	sep_as_regex bool
}

fn args() ([]string, Settings) {
	mut fp := common.flag_parser(os.args)

	fp.application(app_name)
	fp.description(app_description)

	before := fp.bool('before', `b`, false, 'attach the separator before instead of after')
	sep_as_regex := fp.bool('regex', `r`, false, 'interpret the separator as regular expression')
	separator := fp.string('separator', `s`, '\n', 'use <string> as the separator instead of newline')

	mut files := fp.finalize() or { []string{} }

	if '-' in files {
		files = []string{}
	}

	return files, Settings{separator, before, sep_as_regex}
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
