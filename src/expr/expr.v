module main

import os
import strconv

const appname = 'expr'

const version = 'v0.0.1'

const usage = '$appname $version
----------------------------------------------
Usage: expr EXPRESSION
   or: expr OPTION

Options:
  --help                   display this help and exit
  --version                output version information and exit'

type Value = string | i64

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
			exit(1)
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
	match result {
		string {
			if result == '' {
				exit(1)
			}
		}
		i64 {
			if result == 0 {
				exit(1)
			}
		}
	}
	exit(0)
}

fn (mut p Parser) expr(prec int) Value {
	mut left := p.primary()
	mut operator := p.get() or {
		return left
	}
	for prec < precedence(operator) {
		p.idx++
		right := p.expr(precedence(operator))
		left = calc_infix(operator, left, right)
		operator = p.get() or {
			return left
		}
	}
	return left
}

const max_i64 = 9223372036854775807
const min_i64 = -max_i64 - 1

fn calc_infix(operator string, left Value, right Value) Value {
	match operator {
		'+' {
			lnum := left.i64()
			rnum := right.i64()
			if (0 < left && max_i64 - left < right) || (0 > left && min_i64 - left > right) { // overflow check
				my_panic('result out of range', 2)
			}
			return lnum + rnum
		}
		'-' {
			lnum := left.i64()
			rnum := right.i64()
			if (0 < right && min_i64 + right > left) || (0 > right && max_i64 + right < left) { // overflow check
				my_panic('result out of range', 2)
			}
			return lnum + rnum
		}
		else { my_panic('expect operator', 2) }
	}
}

fn (mut p Parser) primary() Value {
	tok := p.get() or {
		my_panic('missing argument after `${p.tokens[p.idx - 1]}`', 2)
	}
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
		'match' { panic('unimplemented') }
		'substr' { panic('unimplemented') }
		'index' { panic('unimplemented') }
		'length' {
			val := p.primary()
			return i64(val.str().len)
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
		string { return strconv.common_parse_int(v, 0, 64, false, false) or { my_panic(err.msg, 2) } }
		i64 { return v }
	}
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
