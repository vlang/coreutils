module main

import os

const unarys = [
	'-b',
	'-c',
	'-d',
	'-e',
	'-f',
	'-g',
	'-h',
	'-L',
	'-n',
	'-p',
	'-r',
	'-S',
	'-s',
	'-t',
	'-u',
	'-w',
	'-x',
	'-z',
]

const binarys = [
	'=',
	'!=',
	'==',
	'-nt',
	'-ot',
	'-ef',
	'-eq',
	'-ne',
	'-lt',
	'-le',
	'-gt',
	'-ge',
]

[noreturn]
fn my_panic(s string) {
	eprintln(s)
	exit(2)
}

fn main() {
	is_lsb := os.args[0].ends_with('[') || os.args[0].ends_with('[.exe')
	if is_lsb && os.args.last() != ']' {
		my_panic('missing `]`')
	}
	match os.args.len - int(is_lsb) {
		1 {
			exit(1)
		}
		2 {
			exit(if os.args[1] == '' { 1 } else { 0 })
		}
		3 {
			if os.args[1] == '!' {
				exit(if os.args[2] == '' { 0 } else { 1 })
			}
			if os.args[1] in unarys {
				exit(if test_unary(os.args[1][1], os.args[2]) { 0 } else { 1 })
			}
			my_panic('expect unary operator')
		}
		else {
			mut parser := Parser{
				tokens: os.args[1..]
				idx: 0
			}
			result := if parser.expr() { 0 } else { 1 }
			if parser.idx + u64(is_lsb) < parser.tokens.len {
				my_panic('unexpected argument `${parser.tokens[parser.idx]}`')
			}
			exit(result)
		}
	}
}

struct Parser {
	tokens []string
mut:
	idx u64
}

fn (mut p Parser) expr() bool {
	mut b := p.and()
	mut tok := p.get() or {
		return b
	}
	for tok == '-o' {
		p.idx++
		b = b || p.and()
		tok = p.get() or {
			return b
		}
	}
	return b
}

fn (mut p Parser) and() bool {
	mut b := p.term()
	mut tok := p.get() or {
		return b
	}
	for tok == '-a' {
		p.idx++
		b = b && p.term()
		tok = p.get() or {
			return b
		}
	}
	return b
}

fn (mut p Parser) term() bool {
	mut is_neg := false
	mut tok := p.get() or {
		my_panic('expect expression after `${p.tokens[p.idx - 1]}`')
	}
	for tok == '!' {
		is_neg = !is_neg
		p.idx++
		tok = p.get() or {
			my_panic('expect expression after `!`')
		}
	}
	p.idx++
	return is_neg != (tok != '') // this means is_neg ^ (tok != '')
}

[inline]
fn (p Parser) get() ?string {
	if p.idx < p.tokens.len {
		return p.tokens[p.idx]
	}
	return none
}

fn test_unary(option byte, arg string) bool { return true }
