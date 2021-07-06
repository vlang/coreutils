import os
import strings

fn is_hex_char(c byte) bool {
	return match c {
		`0`...`9`, `a`...`f`, `A`...`F` { true }
		else { false }
	}
}

fn hex_to_byte(c byte) byte {
	return match c {
		`a`, `A` { 10 }
		`b`, `B` { 11 }
		`c`, `C` { 12 }
		`d`, `D` { 13 }
		`e`, `E` { 14 }
		`f`, `F` { 15 }
		else { c - `0` }
	}
}

fn is_octal_char(c byte) bool {
	return `0` <= c && c <= `7`
}

fn octal_to_byte(c byte) byte {
	return c - 48
}

fn unescape(str string) string {
	mut res := strings.new_builder(str.len)
	mut idx := 0

	for idx < str.len {
		mut c := str[idx]
		idx++
		if c == `\\` {
			c = str[idx] or {
				res.write_b(`\\`)
				return res.str()
			}
			idx++
			match c {
				`a` {
					c = `\a`
				}
				`b` {
					c = `\b`
				}
				`c` {
					return res.str()
				}
				`e` {
					c = `\e`
				}
				`f` {
					c = `\f`
				}
				`n` {
					c = `\n`
				}
				`r` {
					c = `\r`
				}
				`t` {
					c = `\t`
				}
				`v` {
					c = `\v`
				}
				`0` {
					mut ch := str[idx] or { continue }
					if is_octal_char(ch) {
						for _ in 0 .. 2 {
							idx++
							c = octal_to_byte(ch)
							ch = str[idx] or { continue }
							if is_octal_char(ch) {
								c = c * 8 + octal_to_byte(ch)
							} else {
								break
							}
						}
					} else {
						res.write_b(`\\`)
					}
				}
				`x` {
					mut ch := str[idx] or { continue }
					if is_hex_char(ch) {
						idx++
						c = hex_to_byte(ch)
						ch = str[idx] or { continue }
						if is_hex_char(ch) {
							idx++
							c = c * 16 + hex_to_byte(ch)
						}
					} else {
						res.write_b(`\\`)
					}
				}
				else {
					res.write_b(`\\`)
				}
			}
		}
		res.write_b(c)
	}

	return res.str()
}

const (
	usage = 'Usage: echo [SHORT-OPTION]... [STRING]...
or: echo LONG-OPTION
Echo the STRING(s) to standard output.

  -n             do not output the trailing newline
  -e             enable interpretation of backslash escapes
  -E             disable interpretation of backslash escapes (default)
      --help     display this help and exit
      --version  output version information and exit'
	version = 'echo (V coreutils) 0.0.1'
)

fn main() {
	mut idx := 1
	mut append_newline := true
	mut interpret_escapes := false
	for idx < os.args.len {
		match os.args[idx] {
			'--help' {
				println(usage)
				exit(0)
			}
			'--version' {
				println(version)
				exit(0)
			}
			'-n' {
				append_newline = false
			}
			'-e' {
				interpret_escapes = true
			}
			'-E' {
				interpret_escapes = false
			}
			else {
				break
			}
		}
		idx++
	}
	mut str := os.args[idx..].join(' ')
	if append_newline {
		str += '\n'
	}
	if interpret_escapes {
		str = unescape(str)
	}
	print(str)
}
