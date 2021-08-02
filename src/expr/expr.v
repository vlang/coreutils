module main

import os
import strings
import strconv
import regex
import common

const appname = 'expr'

const version = 'v0.0.1'

const usage = '$appname $version
----------------------------------------------
Usage: expr EXPRESSION
   or: expr OPTION

Options:
  --help                   display this help and exit
  --version                output version information and exit'

const locale = common.is_utf8()

type Value = i64 | string

struct Parser {
	tokens []string
mut:
	idx u64
}

[noreturn]
fn my_panic(err string, code int) {
	eprintln(err)
	exit(code)
}

fn main() {
	match os.args.len {
		1 {
			eprintln(usage)
			exit(2)
		}
		2 {
			match os.args[1] {
				'--help' {
					println(usage)
					exit(0)
				}
				'--version' {
					println('$appname $version')
					exit(0)
				}
				else {}
			}
		}
		else {}
	}

	mut parser := Parser{
		tokens: os.args[1..]
	}
	result := parser.expr(-1)
	if parser.idx < parser.tokens.len {
		my_panic('unexpected argument `${parser.tokens[parser.idx]}`', 2)
	}
	println(match result {
		string { result }
		i64 { result.str() }
	})
	exit(int(result.is_null()))
}

fn (mut p Parser) expr(prec int) Value {
	mut left := p.primary()
	mut operator := p.get() or { return left }
	for prec < precedence(operator) {
		p.idx++
		right := p.expr(precedence(operator))
		left = calc_infix(operator, left, right)
		operator = p.get() or { return left }
	}
	return left
}

const max_i64 = i64(9223372036854775807)

const min_i64 = -max_i64 - 1

fn calc_infix(operator string, left Value, right Value) Value {
	match operator {
		'|' {
			return if left.is_null() { right } else { left }
		}
		'&' {
			if left.is_null() || right.is_null() {
				return i64(0)
			}
			return left
		}
		'<' {
			if lnum := left.i64_opt() {
				if rnum := right.i64_opt() {
					return i64(lnum < rnum)
				}
			}
			return i64(left.str() < right.str())
		}
		'<=' {
			if lnum := left.i64_opt() {
				if rnum := right.i64_opt() {
					return i64(lnum <= rnum)
				}
			}
			return i64(left.str() <= right.str())
		}
		'=' {
			if lnum := left.i64_opt() {
				if rnum := right.i64_opt() {
					return i64(lnum == rnum)
				}
			}
			return i64(left.str() == right.str())
		}
		'!=' {
			if lnum := left.i64_opt() {
				if rnum := right.i64_opt() {
					return i64(lnum != rnum)
				}
			}
			return i64(left.str() != right.str())
		}
		'>=' {
			if lnum := left.i64_opt() {
				if rnum := right.i64_opt() {
					return i64(lnum >= rnum)
				}
			}
			return i64(left.str() >= right.str())
		}
		'>' {
			if lnum := left.i64_opt() {
				if rnum := right.i64_opt() {
					return i64(lnum > rnum)
				}
			}
			return i64(left.str() > right.str())
		}
		'+' {
			lnum := left.i64()
			rnum := right.i64()
			if (0 < lnum && max_i64 - lnum < rnum) || (0 > lnum && min_i64 - lnum > rnum) { // overflow check
				my_panic('result out of range', 2)
			}
			return lnum + rnum
		}
		'-' {
			lnum := left.i64()
			rnum := right.i64()
			if (0 < rnum && min_i64 + rnum > lnum) || (0 > rnum && max_i64 + rnum < lnum) { // overflow check
				my_panic('result out of range', 2)
			}
			return lnum - rnum
		}
		'*' {
			return left.i64() * right.i64()
		}
		'/' {
			lnum := left.i64()
			rnum := right.i64()
			if rnum == 0 {
				my_panic('division by 0', 2)
			}
			return lnum / rnum
		}
		'%' {
			lnum := left.i64()
			rnum := right.i64()
			if rnum == 0 {
				my_panic('division by 0', 2)
			}
			return lnum % rnum
		}
		':' {
			return match_str(left.str(), right.str())
		}
		else {
			my_panic('expect operator', 2)
		}
	}
}

fn match_str(s string, _m string) Value {
	m := replace_regex(_m)
	mut re := regex.regex_opt(m) or { my_panic('invalid regular expression', 2) }
	re.flag |= regex.f_ms
	start, end := re.match_string(s)
	if re.group_count > 0 {
		if re.groups[0] == -1 {
			return ''
		} else {
			ret := s[re.groups[0]..re.groups[1]]
			return ret
		}
	} else {
		return i64(if start == -1 {
			0
		} else if locale {
			utf8_str_len(s[start..end])
		} else {
			end - start
		})
	}
}

// \( <=> (, \) <=> ), \+ <=> +, ...etc
fn replace_regex(s string) string {
	mut out := strings.new_builder(s.len)
	mut is_escape := false
	for i in s {
		match i {
			`\\` {
				if is_escape {
					out.write_string('\\\\')
				}
				is_escape = !is_escape
			}
			`(`, `)`, `{`, `}`, `+`, `?`, `|` {
				if is_escape {
					out.write_b(i)
				} else {
					out.write_string('\\' + i.ascii_str())
				}
				is_escape = false
			}
			else {
				if is_escape {
					out.write_b(`\\`)
				}
				out.write_b(i)
				is_escape = false
			}
		}
	}
	if is_escape {
		my_panic('trailing backslash', 2)
	}
	return out.str()
}

fn (mut p Parser) primary() Value {
	tok := p.get() or { my_panic('missing argument after `${p.tokens[p.idx - 1]}`', 2) }
	p.idx++
	match tok {
		'(' {
			val := p.expr(-1)
			if tok2 := p.get() {
				if tok2 == ')' {
					p.idx++
					return val
				}
			}
			my_panic('expect `)` after `${p.tokens[p.idx - 1]}`', 2)
		}
		'+' {
			if tok2 := p.get() {
				p.idx++
				return tok2
			}
			my_panic('missing argument after `+`', 2)
		}
		'match' {
			s := p.primary()
			m := p.primary()
			return match_str(s.str(), m.str())
		}
		'substr' {
			s := p.primary()
			o := p.primary()
			l := p.primary()

			str := s.str()
			pos := o.i64_opt() or { 0 }
			len := l.i64_opt() or { 0 }
			if pos < 1 || len < 1 {
				return ''
			}
			if locale {
				ustr := str.runes()
				start := if ustr.len < pos - 1 { i64(ustr.len) } else { pos - 1 }
				end := if ustr.len < start + len { i64(ustr.len) } else { start + len }
				ret := ustr[start..end]
				return ret.string()
			} else {
				start := if str.len < pos - 1 { i64(str.len) } else { pos - 1 }
				end := if str.len < start + len { i64(str.len) } else { start + len }
				ret := str[start..end]
				return ret
			}
		}
		'index' {
			str := p.primary().str()
			chr := p.primary().str()
			if locale {
				ustr := str.runes()
				uchr := chr.runes()
				for i, r in ustr {
					if r in uchr {
						return i64(i + 1)
					}
				}
				return i64(0)
			} else {
				for i, r in str {
					if chr.index_byte(r) != -1 {
						return i64(i + 1)
					}
				}
				return i64(0)
			}
		}
		'length' {
			val := p.primary().str()
			return i64(if locale {
				utf8_str_len(val)
			} else {
				val.len
			})
		}
		else {
			return tok
		}
	}
}

[inline]
fn (p Parser) get() ?string {
	if p.idx < p.tokens.len {
		return p.tokens[p.idx]
	}
	return none
}

fn (v Value) str() string {
	return match v {
		string { v }
		i64 { v.str() }
	}
}

fn (v Value) i64() i64 {
	match v {
		string { return strconv.parse_int(v, 0, 64) or { my_panic(err.msg, 2) } }
		i64 { return v }
	}
}

fn (v Value) i64_opt() ?i64 {
	match v {
		string { return strconv.parse_int(v, 0, 64) }
		i64 { return v }
	}
}

fn (v Value) is_null() bool {
	match v {
		string {
			if v == '' {
				return true
			}
			if a := strconv.parse_int(v, 0, 64) {
				if a == 0 {
					return true
				}
			}
		}
		i64 {
			if v == 0 {
				return true
			}
		}
	}
	return false
}

fn precedence(s string) int {
	return match s {
		'|' { 0 }
		'&' { 1 }
		'<', '<=', '=', '!=', '>=', '>' { 2 }
		'+', '-' { 3 }
		'*', '/', '%' { 4 }
		':' { 5 }
		else { -1 }
	}
}
