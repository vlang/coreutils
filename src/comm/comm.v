module main

import os
import io
import common

struct Settings {
	suppress_col1    bool
	suppress_col2    bool
	suppress_col3    bool
	check_order      bool
	nocheck_order    bool
	output_delimiter string
	zero_terminated  bool
	show_total       bool
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('comm')
	fp.description('Compare two sorted files line by line')
	fp.version(common.coreutils_version())

	suppress_col1 := fp.bool('', `1`, false, 'suppress column 1 (lines unique to FILE1)')
	suppress_col2 := fp.bool('', `2`, false, 'suppress column 2 (lines unique to FILE2)')
	suppress_col3 := fp.bool('', `3`, false, 'suppress column 3 (lines that appear in both files)')
	check_order := fp.bool('check-order', 0, false, 'check that the input is correctly sorted, even if all input lines are pairable')
	nocheck_order := fp.bool('nocheck-order', 0, false, 'do not check that the input is correctly sorted')
	output_delimiter := fp.string('output-delimiter', 0, '\t', 'separate columns with STRING')
	zero_terminated := fp.bool('zero-terminated', `z`, false, 'line delimiter is NUL, not newline')
	total := fp.bool('total', 0, false, 'output a summary')

	positional_args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		exit(1)
	}

	if positional_args.len != 2 {
		eprintln('comm: missing operand')
		eprintln("Try 'comm --help' for more information.")
		exit(1)
	}

	settings := Settings{
		suppress_col1:    suppress_col1
		suppress_col2:    suppress_col2
		suppress_col3:    suppress_col3
		check_order:      check_order
		nocheck_order:    nocheck_order
		output_delimiter: output_delimiter
		zero_terminated:  zero_terminated
		show_total:       total
	}

	run(settings, positional_args[0], positional_args[1])
}

fn run(settings Settings, file1_path string, file2_path string) {
	mut file1 := open_file_or_stdin(file1_path) or {
		common.exit_with_error_message('comm', '${err}')
	}
	defer {
		file1.close()
	}

	mut file2 := open_file_or_stdin(file2_path) or {
		common.exit_with_error_message('comm', '${err}')
	}
	defer {
		file2.close()
	}

	mut reader1 := io.new_buffered_reader(reader: file1)
	mut reader2 := io.new_buffered_reader(reader: file2)

	delimiter := if settings.zero_terminated { `\0` } else { `\n` }

	mut line1 := read_line(mut reader1, delimiter) or { '' }
	mut line2 := read_line(mut reader2, delimiter) or { '' }
	mut prev_line1 := ''
	mut prev_line2 := ''

	mut col1_count := 0
	mut col2_count := 0
	mut col3_count := 0

	check_order := !settings.nocheck_order && settings.check_order

	for {
		// Check sort order if needed
		if check_order {
			if line1 != '' && prev_line1 != '' && line1 < prev_line1 {
				eprintln('comm: file 1 is not in sorted order')
				exit(1)
			}
			if line2 != '' && prev_line2 != '' && line2 < prev_line2 {
				eprintln('comm: file 2 is not in sorted order')
				exit(1)
			}
		}

		// Both files exhausted
		if line1 == '' && line2 == '' {
			break
		}

		// File 2 exhausted or line1 comes before line2
		if line2 == '' || (line1 != '' && line1 < line2) {
			if !settings.suppress_col1 {
				print_column(1, line1, settings)
			}
			col1_count++
			prev_line1 = line1
			line1 = read_line(mut reader1, delimiter) or { '' }
		}
		// File 1 exhausted or line2 comes before line1
		else if line1 == '' || line2 < line1 {
			if !settings.suppress_col2 {
				print_column(2, line2, settings)
			}
			col2_count++
			prev_line2 = line2
			line2 = read_line(mut reader2, delimiter) or { '' }
		}
		// Lines are equal
		else {
			if !settings.suppress_col3 {
				print_column(3, line1, settings)
			}
			col3_count++
			prev_line1 = line1
			prev_line2 = line2
			line1 = read_line(mut reader1, delimiter) or { '' }
			line2 = read_line(mut reader2, delimiter) or { '' }
		}
	}

	if settings.show_total {
		if !settings.suppress_col1 {
			print('${col1_count}')
		}
		if !settings.suppress_col2 {
			if !settings.suppress_col1 {
				print(settings.output_delimiter)
			}
			print('${col2_count}')
		}
		if !settings.suppress_col3 {
			if !settings.suppress_col1 || !settings.suppress_col2 {
				print(settings.output_delimiter)
			}
			print('${col3_count}')
		}
		print('\ttotal\n')
	}
}

fn open_file_or_stdin(path string) !os.File {
	if path == '-' {
		return os.stdin()
	}
	return os.open(path)!
}

fn read_line(mut reader io.BufferedReader, delimiter u8) !string {
	line := reader.read_line(delim: delimiter)!
	if line.len > 0 && line[line.len - 1] == delimiter {
		return line[..line.len - 1]
	}
	return line
}

fn print_column(column int, text string, settings Settings) {
	mut prefix := ''

	// Add tabs based on which columns are being printed
	match column {
		1 {
			// Column 1 has no prefix
		}
		2 {
			// Column 2 has one tab if column 1 is being printed
			if !settings.suppress_col1 {
				prefix = settings.output_delimiter
			}
		}
		3 {
			// Column 3 has tabs for each unsuppressed column before it
			if !settings.suppress_col1 {
				prefix += settings.output_delimiter
			}
			if !settings.suppress_col2 {
				prefix += settings.output_delimiter
			}
		}
		else {}
	}

	if settings.zero_terminated {
		print('${prefix}${text}\0')
	} else {
		println('${prefix}${text}')
	}
}
