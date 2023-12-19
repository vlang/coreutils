import os
import common
import strings

fn is_hex_char(c u8) bool {
	return match c {
		`0`...`9`, `a`...`f`, `A`...`F` { true }
		else { false }
	}
}

fn hex_to_byte(c u8) u8 {
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

fn is_octal_char(c u8) bool {
	return `0` <= c && c <= `7`
}

fn octal_to_byte(c u8) u8 {
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
				res.write_byte(`\\`)
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
						res.write_byte(`\\`)
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
						res.write_byte(`\\`)
					}
				}
				else {
					res.write_byte(`\\`)
				}
			}
		}
		res.write_byte(c)
	}

	return res.str()
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('echo')
	fp.description('Echo a string to standard output')
	fp.limit_free_args_to_at_least(1)!
	no_newline := fp.bool('no_newline', `n`, false, 'do not output a trailing newline')
	interpret_escapes := fp.bool('interpret_escapes', `e`, false, 'enable interpretation of backslash escapes')

	mut str_a := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	mut str := str_a.join(' ')

	if no_newline == false {
		str += '\n'
	}
	if interpret_escapes {
		str = unescape(str)
	}
	print(str)
}
