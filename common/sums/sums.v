module sums

import common
import os

// sum is the common routine for *sum commands: md5sum, sha1sum, sha224sum, ...
pub fn sum(args []string, sum_name string, sum_type string, num_chars_in_sum int, sum_fn fn (data []byte) []byte) {
	mut fp := common.flag_parser(args)
	fp.application(sum_name)
	fp.arguments_description('[OPTION]... [FILE]...')
	fp.description('Print or check $sum_type checksums.')
	fp.description('')
	fp.description('With no FILE, or when FILE is -, read standard input.')

	binary := fp.bool('binary', `b`, false, 'read in binary mode')
	check := fp.bool('check', `c`, false, 'read $sum_type sums from the FILEs and check them')
	tag := fp.bool('tag', 0, false, 'create a BSD-style checksum')
	_ := fp.bool('text', `t`, false, 'read in text mode (default)') // accepted but ignored, just like GNU
	// yes, the spaces are needed in the next line, to make the 'help' output line up
	zero := fp.bool('zero', `z`, false, 'end each output line with NUL, not newline,\n                            and disable file name escaping')

	ignore_missing := fp.bool('ignore-missing', 0, false, "(only with -c) don't fail or report status for missing files")
	quiet := fp.bool('quiet', 0, false, "(only with -c) don't print OK for each successfully verified file")
	status := fp.bool('status', 0, false, "(only with -c) don't output anything, status code shows success")
	strict := fp.bool('strict', 0, false, '(only with -c) exit non-zero for improperly formatted checksum lines')
	warn := fp.bool('warn', `w`, false, '(only with -c) warn about improperly formatted checksum lines')

	mut files := fp.finalize() or {
		eprintln("${args[0]}: $err.msg\nTry '${args[0]} --help' for more information.")
		exit(1)
	}

	prefix := if binary { '*' } else { ' ' }
	eol := if zero { '\x0' } else { '\n' }
	mut bytes := []byte{}

	if files.len < 1 {
		files << '-'
	}

	mut no_read := 0
	mut bad_sum := 0
	mut bad_sum_line := 0
	mut rc := 0

	for file in files {
		if os.is_dir(file) {
			eprintln('${args[0]}: $file: Is a directory')
			continue
		}

		if !os.exists(file) {
			eprintln('${args[0]}: $file: No such file or directory')
			continue
		}

		if check {
			mut lines := []string{}

			if file == '-' {
				lines = os.get_lines()
			} else {
				lines = os.read_lines(file) or {
					eprintln('${args[0]}: $file: FAILED open or read')
					continue
				}
			}

			mut file_to_check := ''
			mut sum_to_check := ''

			for i, line in lines {
				mut pieces := line.split(' ')

				if pieces[0] == sum_type {
					if pieces[1].starts_with('(') && pieces[1].ends_with(')') {
						pieces[1] = pieces[1][1..pieces[1].len - 1]
					}

					file_to_check = pieces[1]
					sum_to_check = pieces[3]
				} else {
					sum_to_check = pieces[0]

					if pieces.len == 2 {
						if pieces[1].starts_with('*') {
							pieces[1] = pieces[1][1..]
						}

						file_to_check = pieces[1]
					} else {
						file_to_check = pieces[2]
					}
				}

				if sum_to_check.len != num_chars_in_sum {
					bad_sum_line++

					if warn {
						eprintln('${args[0]}: $file: ${i + 1}: improperly formatted $sum_type checksum line')
					}

					continue
				} else {
					mut all_hex := true
					for c in sum_to_check {
						if !c.is_hex_digit() {
							all_hex = false
							break
						}
					}

					if !all_hex {
						bad_sum_line++
						continue
					}
				}

				if file_to_check == '-' {
					stdin := os.get_raw_lines_joined()
					bytes = stdin.bytes()
				} else {
					if !os.exists(file_to_check) {
						eprintln('${args[0]}: $file_to_check: No such file or directory')
					}

					bytes = os.read_bytes(file_to_check) or {
						if !ignore_missing {
							no_read++
							eprintln('$file_to_check FAILED open or read')
						}
						continue
					}
				}

				sum := sum_fn(bytes)

				if sum_to_check == sum.hex() {
					if !quiet && !status {
						println('$file_to_check OK')
					}
				} else {
					bad_sum++
					if !status {
						println('$file_to_check FAILED')
					}
				}
			}

			if bad_sum_line > 0 {
				if !status {
					plural_msg := if bad_sum_line == 1 { 'line is' } else { 'lines are' }
					eprintln('${args[0]}: WARNING: $bad_sum_line $plural_msg improperly formatted')
				}

				rc = if strict { 1 } else { 0 }
			}

			if no_read > 0 {
				if !status {
					plural_msg := if no_read == 1 { 'listed file' } else { 'listed files' }
					eprintln('${args[0]}: WARNING: $no_read $plural_msg could not be read')
				}

				rc = 1
			}

			if bad_sum > 0 {
				if !status {
					plural_msg := if bad_sum == 1 {
						'computed checksum'
					} else {
						'computed checksums'
					}
					eprintln('${args[0]}: WARNING: $bad_sum $plural_msg did NOT match')
				}

				rc = 1
			}
		} else {
			if file == '-' {
				stdin := os.get_raw_lines_joined()
				bytes = stdin.bytes()
			} else {
				bytes = os.read_bytes(file) or {
					if !ignore_missing {
						no_read++
						eprintln('$file FAILED open or read')
					}
					continue
				}
			}

			sum := sum_fn(bytes)

			if tag {
				print('$sum_type ($file) = $sum.hex()$eol')
			} else {
				print('$sum.hex() $prefix$file$eol')
			}
		}
	}

	exit(rc)
}
