import os
import arrays

const max_buf_len = 4096

fn main() {
	options := get_options()
	paste(options, fn [options] (s string) {
		match options.zero_terminated {
			true { print(s + '\0') }
			else { println(s) }
		}
	})
}

fn paste(options Options, cb_output fn (string)) {
	if options.serial {
		for file in options.files {
			lines := os.read_lines(file) or { exit_error(err.msg()) }
			cb_output(lines.join(options.next_delimiter(false)))
			options.next_delimiter(true) // reset
		}
		return
	}

	// parallel
	mut file_lines := [][]string{}
	for file in options.files {
		file_lines << os.read_lines(file) or { exit_error(err.msg()) }
	}
	mut idx := 0
	max_lines := arrays.max(file_lines.map(it.len)) or { exit_error(err.msg()) }
	for _ in 0 .. max_lines {
		mut buf := ''
		for i, line in file_lines {
			buf += line[idx] or { '' }
			if i < file_lines.len - 1 {
				buf += options.next_delimiter(false)
			}
		}
		cb_output(buf)
		options.next_delimiter(true) // reset
		idx += 1
	}
}
