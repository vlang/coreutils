import common
import io
import os

const app_name = 'tr'

struct Settings {
mut:
	delete     bool
	squeeze    bool
	complement bool
	set1       string
	set2       string
}

fn main() {
	set := args()!
	tr(set)
}

fn tr(set Settings) {
	input := io.read_all(io.ReadAllConfig{reader: os.stdin()}) or { []u8{} }
	mut output := []u8{}

	if set.delete && set.squeeze {
		mut prev := u8(0)
		for b in input {
			if set.set1.contains(b.ascii_str()) {
				continue
			}
			if set.set2.len > 0 && set.set2.contains(b.ascii_str()) && b == prev {
				continue
			}
			output << b
			prev = b
		}
	} else if set.delete {
		for b in input {
			if set.set1.contains(b.ascii_str()) {
				continue
			}
			output << b
		}
	} else if set.squeeze {
		mut prev := u8(0)
		for b in input {
			if set.set1.contains(b.ascii_str()) && b == prev {
				continue
			}
			output << b
			prev = b
		}
	} else {
		for b in input {
			idx := set.set1.index(b.ascii_str()) or { -1 }
			if idx >= 0 && idx < set.set2.len {
				output << set.set2[idx]
			} else if set.complement {
				if set.set2.len > 0 {
					output << set.set2[0]
				}
			} else {
				output << b
			}
		}
	}

	mut stdout := os.stdout()
	stdout.write(output) or { exit(1) }
}

fn parse_set(s string) string {
	mut result := ''
	mut i := 0
	for i < s.len {
		if s[i] == `\\` && i + 1 < s.len {
			i++
			match s[i] {
				`n` { result += '\n' }
				`t` { result += '\t' }
				`r` { result += '\r' }
				`\\` { result += '\\' }
				else { result += s[i].ascii_str() }
			}
			i++
		} else if s[i] == `[` && i + 2 < s.len && s[i + 1] == `:` {
			end := s.index_after(']', i + 2) or { s.len }
			class := s[i + 2..end]
			match class {
				'alpha' {
					for c in u8(`a`)..u8(`z`) {
						result += c.ascii_str()
					}
					for c in u8(`A`)..u8(`Z`) {
						result += c.ascii_str()
					}
				}
				'digit' {
					for c in u8(`0`)..u8(`9`) {
						result += c.ascii_str()
					}
				}
				'space' {
					result += ' \t\n\r'
				}
				'lower' {
					for c in u8(`a`)..u8(`z`) {
						result += c.ascii_str()
					}
				}
				'upper' {
					for c in u8(`A`)..u8(`Z`) {
						result += c.ascii_str()
					}
				}
				else {}
			}
			i = end + 1
		} else if i + 2 < s.len && s[i + 1] == `-` {
			start := s[i]
			end_ch := s[i + 2]
			for c in u8(start)..u8(end_ch) {
				result += c.ascii_str()
			}
			i += 3
		} else {
			result += s[i].ascii_str()
			i++
		}
	}
	return result
}

fn args() !Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('Translate, squeeze, and/or delete characters from standard input, writing to standard output.')

	delete := fp.bool('delete', `d`, false, 'delete characters in SET1, do not translate')
	squeeze := fp.bool('squeeze-repeats', `s`, false, 'replace each sequence of a repeated character that is listed in the last specified SET, with a single occurrence of that character')
	complement := fp.bool('complement', `c`, false, 'use the complement of SET1')

	fp.allow_unknown_args()
	fp.finalize()!

	rest := fp.remaining_parameters()
	if rest.len == 0 {
		common.exit_with_error_message(app_name, 'missing operand')
	}
	if !delete && !squeeze && rest.len < 2 {
		common.exit_with_error_message(app_name, 'missing operand after \'${rest[0]}\'')
	}

	mut set1 := ''
	mut set2 := ''
	if delete || squeeze {
		set1 = parse_set(rest[0])
		if squeeze && rest.len > 1 {
			set2 = parse_set(rest[1])
		}
	} else {
		set1 = parse_set(rest[0])
		set2 = parse_set(rest[1])
	}

	return Settings{
		delete:     delete
		squeeze:    squeeze
		complement: complement
		set1:       set1
		set2:       set2
	}
}
