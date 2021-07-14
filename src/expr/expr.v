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
	result := parser.expr()
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

fn (mut p Parser) expr() Value {
	return Value('')
}

fn (mut p Parser) primary() Value {
	tok := p.get() or {
		panic('missing argument after `${p.tokens[p.idx - 1]}`')
	}
	match tok {
		'(' {
			p.idx++
			val := p.expr()
			if tok2 := p.get() {
				if tok2 == ')' {
					p.idx++
					return val
				}
			}
			panic('expect `)` after `${p.tokens[p.idx - 1]}`')
		}
		'+' {
			p.idx++
			if tok2 := p.get() {
				return tok2
			}
			panic('missing argument after `+`')
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
		string { return strconv.common_parse_int(v, 0, 64, false, false) or { panic(err) } }
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
		else { panic('unexpected token `$s`') (-1) }
	}
}
