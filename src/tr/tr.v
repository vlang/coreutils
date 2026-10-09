import common
import io
import os

const app_name = 'tr'

struct Settings {
mut:
	delete     bool
	squeeze    bool
	complement bool
	truncate   bool
	set1       string
	set2       string
}

fn main() {
	set := args()!
	tr(set)
}

fn tr(set Settings) {
	input := io.read_all(io.ReadAllConfig{ reader: os.stdin() }) or { []u8{} }
	mut output := []u8{}

	if set.delete && set.squeeze {
		mut prev := u8(0)
		for b in input {
			in_set1 := set.set1.contains(b.ascii_str())
			if (!in_set1 && set.complement) || (in_set1 && !set.complement) {
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
			in_set1 := set.set1.contains(b.ascii_str())
			if (!in_set1 && set.complement) || (in_set1 && !set.complement) {
				continue
			}
			output << b
		}
	} else if set.squeeze && set.set2.len == 0 {
		// Squeeze-only: -s with a single SET. (-s with two SETs translates
		// first and is handled below. An explicitly empty SET2 is rejected
		// while parsing arguments.)
		mut prev := u8(0)
		for b in input {
			in_set1 := set.set1.contains(b.ascii_str())
			squeezable := (!in_set1 && set.complement) || (in_set1 && !set.complement)
			if squeezable && b == prev {
				continue
			}
			output << b
			prev = b
		}
	} else {
		// With -c, SET1 is replaced by its complement: every byte not in
		// SET1, in byte order. Characters in SET1 then pass through.
		// With -t, the effective SET1 is truncated to the length of SET2,
		// after complementing. (On `tr -ct` uutils 0.0.17 translates every
		// byte to the last character of SET2 instead, which disagrees with
		// GNU 9.4; this port follows GNU, and that combination is
		// deliberately untested against the reference.)
		mut eff_set1 := if set.complement { complement_of(set.set1) } else { set.set1 }
		if set.truncate && eff_set1.len > set.set2.len {
			eff_set1 = eff_set1[..set.set2.len]
		}
		mut prev := u8(0)
		mut have_prev := false
		for b in input {
			idx := eff_set1.index(b.ascii_str()) or { -1 }
			mut tb := b
			if idx >= 0 {
				if idx < set.set2.len {
					tb = set.set2[idx]
				} else if set.set2.len > 0 {
					// A short SET2 is extended by repeating its last character.
					tb = set.set2[set.set2.len - 1]
				}
			}
			// With -s and two SETs, repeats of SET2 characters are squeezed
			// after translation.
			if set.squeeze && set.set2.len > 0 && have_prev && tb == prev
				&& set.set2.contains(tb.ascii_str()) {
				continue
			}
			output << tb
			prev = tb
			have_prev = true
		}
	}

	mut stdout := os.stdout()
	stdout.write(output) or { exit(1) }
}

fn complement_of(s string) string {
	mut present := []bool{len: 256}
	for b in s.bytes() {
		present[int(b)] = true
	}
	mut out := ''
	for i in 0 .. 256 {
		if !present[i] {
			out += u8(i).ascii_str()
		}
	}
	return out
}

fn parse_set(s string, star_pad_to int) string {
	mut result := ''
	mut i := 0
	for i < s.len {
		if s[i] == `\\` && i + 1 < s.len {
			i++
			if s[i] >= `0` && s[i] <= `7` {
				// Octal escape: up to three digits.
				mut val := int(s[i]) - int(`0`)
				mut count := 1
				for count < 3 && i + 1 < s.len && s[i + 1] >= `0` && s[i + 1] <= `7` {
					i++
					val = val * 8 + int(s[i]) - int(`0`)
					count++
				}
				result += u8(val).ascii_str()
				i++
			} else {
				match s[i] {
					`a` { result += u8(0x07).ascii_str() }
					`b` { result += u8(0x08).ascii_str() }
					`f` { result += u8(0x0c).ascii_str() }
					`n` { result += '\n' }
					`t` { result += '\t' }
					`r` { result += '\r' }
					`v` { result += u8(0x0b).ascii_str() }
					`\\` { result += '\\' }
					else { result += s[i].ascii_str() }
				}
				i++
			}
		} else if s[i] == `[` && i + 2 < s.len && s[i + 1] == `:` {
			mut end := s.len
			for j in i + 2 .. s.len {
				if s[j] == `]` {
					end = j
					break
				}
			}
			class := s[i + 2..end]
			// A class has the form [:name:], so drop the trailing ':' from
			// the extracted name. Only strip when a closing ']' was found.
			name := if end < s.len && class.ends_with(':') {
				class[..class.len - 1]
			} else {
				class
			}
			match name {
				'alpha' {
					for c in u8(`a`) .. u8(`z`) + 1 {
						result += c.ascii_str()
					}
					for c in u8(`A`) .. u8(`Z`) + 1 {
						result += c.ascii_str()
					}
				}
				'alnum' {
					for c in u8(`A`) .. u8(`Z`) + 1 {
						result += c.ascii_str()
					}
					for c in u8(`a`) .. u8(`z`) + 1 {
						result += c.ascii_str()
					}
					for c in u8(`0`) .. u8(`9`) + 1 {
						result += c.ascii_str()
					}
				}
				'blank' {
					result += ' \t'
				}
				'cntrl' {
					for c in u8(0x00) .. u8(0x1f) + 1 {
						result += c.ascii_str()
					}
					result += u8(0x7f).ascii_str()
				}
				'digit' {
					for c in u8(`0`) .. u8(`9`) + 1 {
						result += c.ascii_str()
					}
				}
				'space' {
					result += '\t\n'
					result += u8(0x0b).ascii_str()
					result += u8(0x0c).ascii_str()
					result += '\r '
				}
				'lower' {
					for c in u8(`a`) .. u8(`z`) + 1 {
						result += c.ascii_str()
					}
				}
				'upper' {
					for c in u8(`A`) .. u8(`Z`) + 1 {
						result += c.ascii_str()
					}
				}
				'graph' {
					for c in u8(0x21) .. u8(0x7e) + 1 {
						result += c.ascii_str()
					}
				}
				'print' {
					for c in u8(0x20) .. u8(0x7e) + 1 {
						result += c.ascii_str()
					}
				}
				'punct' {
					for c in u8(0x21) .. u8(0x7e) + 1 {
						is_alnum := (c >= u8(`A`) && c <= u8(`Z`)) || (c >= u8(`a`)
							&& c <= u8(`z`)) || (c >= u8(`0`) && c <= u8(`9`))
						if !is_alnum {
							result += c.ascii_str()
						}
					}
				}
				'xdigit' {
					for c in u8(`0`) .. u8(`9`) + 1 {
						result += c.ascii_str()
					}
					for c in u8(`A`) .. u8(`F`) + 1 {
						result += c.ascii_str()
					}
					for c in u8(`a`) .. u8(`f`) + 1 {
						result += c.ascii_str()
					}
				}
				else {}
			}
			i = end + 1
		} else if s[i] == `[` && i + 3 < s.len && s[i + 2] == `*` {
			// Repeat construct [c*] or [c*n]. A bare [c*] pads SET2 out to
			// the length of SET1; it is rejected in SET1 while parsing
			// arguments. star_pad_to carries the SET1 length, or -1 when
			// parsing SET1.
			c := s[i + 1]
			mut j := i + 3
			mut n_str := ''
			for j < s.len && s[j] >= `0` && s[j] <= `9` {
				n_str += s[j].ascii_str()
				j++
			}
			if j < s.len && s[j] == `]` {
				if n_str == '' {
					mut reps := star_pad_to - result.len
					if reps < 0 {
						reps = 0
					}
					for _ in 0 .. reps {
						result += c.ascii_str()
					}
				} else {
					mut n := 0
					if n_str.len > 1 && n_str[0] == `0` {
						for ch in n_str.bytes() {
							n = n * 8 + int(ch) - int(`0`)
						}
					} else {
						for ch in n_str.bytes() {
							n = n * 10 + int(ch) - int(`0`)
						}
					}
					for _ in 0 .. n {
						result += c.ascii_str()
					}
				}
				i = j + 1
			} else {
				result += s[i].ascii_str()
				i++
			}
		} else if i + 2 < s.len && s[i + 1] == `-` {
			start := s[i]
			end_ch := s[i + 2]
			for c in u8(start) .. u8(end_ch) + 1 {
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
	truncate := fp.bool('truncate-set1', `t`, false, 'first truncate SET1 to length of SET2')

	fp.allow_unknown_args()
	fp.finalize()!

	rest := fp.remaining_parameters()
	if rest.len == 0 {
		common.exit_with_error_message(app_name, 'missing operand')
	}
	if !delete && !squeeze && rest.len < 2 {
		common.exit_with_error_message(app_name, "missing operand after '${rest[0]}'")
	}

	mut set1 := ''
	mut set2 := ''
	if has_bare_star(rest[0]) {
		// Exit code and empty output match GNU and uutils. The stderr text
		// matches GNU exactly; uutils 0.0.17 appends a blank line that GNU
		// does not have (measured on this machine), so the tests pin the
		// GNU bytes rather than comparing against the reference here.
		eprintln('${app_name}: the [c*] repeat construct may not appear in string1')
		exit(1)
	}
	if delete || squeeze {
		set1 = parse_set(rest[0], -1)
		if squeeze && rest.len > 1 {
			set2 = parse_set(rest[1], set1.len)
		}
	} else {
		set1 = parse_set(rest[0], -1)
		set2 = parse_set(rest[1], set1.len)
	}
	if !delete && rest.len > 1 && set2.len == 0 && !truncate {
		// Exit code and empty output match GNU and uutils. The stderr text
		// matches GNU exactly; uutils 0.0.17 appends a blank line that GNU
		// does not have (measured on this machine), so the tests pin the
		// GNU bytes rather than comparing against the reference here.
		eprintln('${app_name}: when not truncating set1, string2 must be non-empty')
		exit(1)
	}

	return Settings{
		delete:     delete
		squeeze:    squeeze
		complement: complement
		truncate:   truncate
		set1:       set1
		set2:       set2
	}
}

// has_bare_star reports whether s contains a [c*] repeat construct with no
// repeat count. Backslash-escaped characters are skipped.
fn has_bare_star(s string) bool {
	mut i := 0
	for i + 3 < s.len {
		if s[i] == `\\` {
			i += 2
			continue
		}
		if s[i] == `[` && s[i + 2] == `*` && s[i + 3] == `]` {
			return true
		}
		i++
	}
	return false
}
