module main

import common
import regex
import os

const app = common.CoreutilInfo{
	name:        'tac'
	description: 'concatenate and print files in reverse'
}

const app_name = app.name
const app_description = app.description

struct Settings {
mut:
	before      bool
	regex       bool
	separator   string
	input_files []string
}

// TODO: Should page_size be a global parameter for all coreutils?
const page_size = 8192

fn read_file(file os.File) string {
	mut contents := []u8{}
	for idx := 0; true; idx++ {
		b := file.read_bytes_at(page_size, u64(page_size * idx))
		if b.len == 0 {
			break
		}
		contents << b
	}
	return contents.bytestr()
}

// Find separators and return beginning and end of separator to match
// return of regex find_all()
fn find_sep(s string, sep string) []int {
	mut seps := []int{}
	for i := 0; i <= s.len - sep.len; i++ {
		if s[i..i + sep.len] == sep {
			seps << i
			seps << i + sep.len
		}
	}
	return seps
}

fn process_file(file os.File, settings Settings) {
	mut s := read_file(file)
	mut sep := []int{}
	if settings.regex {
		mut re := regex.regex_opt(settings.separator) or { panic(err) }
		sep = re.find_all(s)
	} else {
		sep = find_sep(s, settings.separator)
	}
	// By adding the beginning and the end, each pair sep[2*n..2*n+1]
	// points to the beginning and end of a separated string
	sep.prepend(0)
	sep << s.len
	assert sep.len % 2 == 0

	for i := sep.len - 2; i >= 0; i -= 2 {
		if settings.before && i > 0 {
			print('${s[sep[i - 1]..sep[i]]}')
		}
		print('${s[sep[i]..sep[i + 1]]}')
		if !settings.before && i < sep.len - 2 {
			print('${s[sep[i + 1]..sep[i + 2]]}')
		}
	}
}

// TODO: Optimization - don't load entire file into memory
fn tac(settings Settings) {
	mut file := os.File{}
	for fname in settings.input_files {
		if fname == '-' {
			file = os.stdin()
		} else {
			file = os.open_file(fname, 'r') or {
				app.quit(message: "failed to open '${fname}' for reading: ${err}")
			}
		}
		process_file(file, settings)
		file.close()
	}
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	st.before = fp.bool('before', `b`, false, 'attach the separator before instead of after')
	st.regex = fp.bool('regex', `r`, false, 'interpret the separator as a regular expression')
	st.separator = fp.string('separator', `s`, '\n', 'use STRING as the separator instead of newline')
	fnames := fp.remaining_parameters()

	if st.separator.len == 0 {
		app.quit(message: 'separator cannot be empty')
	}

	if fnames.len == 0 {
		st.input_files << '-'
	} else {
		st.input_files = fnames
	}

	return st
}

fn main() {
	tac(args())
}
