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
			exit(if os.args[1] != '' { 0 } else { 1 })
		}
		3 {
			exit(if two_args(os.args[1..]) { 0 } else { 1 })
		}
		4 {
			exit(if three_args(os.args[1..]) { 0 } else { 1 })
		}
		5 {
			if result := four_args(os.args[1..]) {
				exit(if result { 0 } else { 1 })
			}
		}
		else {}
	}
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

fn two_args(args []string) bool {
	if args[0] == '!' {
		return args[1] == ''
	}
	if args[0] in unarys {
		return test_unary(args[0][1], args[1])
	}
	my_panic('expect unary operator')
}

fn three_args(args []string) bool {
	return if args[0] == '!' {
		!two_args(args[1..])
	} else if args[1] == '-a' {
		args[0] != '' && args[2] != ''
	} else if args[1] == '-o' {
		args[0] != '' || args[2] != ''
	} else if args[1] in binarys {
		test_binary(args[1], args[0], args[2])
	} else if args[0] == '(' {
		if args[2] != ')' {
			my_panic('expect `)`') false // v magic
		} else {
			args[1] != ''
		}
	} else {
		my_panic('expect binary operator') false // v magic
	}
}

fn four_args(args []string) ?bool {
	if args[0] == '!' {
		return !three_args(args[1..])
	}
	if args[0] == '(' {
		if args[3] != ')' {
			my_panic('expect `)`')
		}
		return two_args(args[1..3])
	}
	return none
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
	if tok == '(' {
		result := is_neg != p.expr()
		if tok2 := p.get() {
			if tok2 == ')' {
				p.idx++
				return result
			}
		}
		my_panic('expect `)`')
	}
	if tok2 := p.get() {
		if tok2 in binarys {
			p.idx++
			if tok3 := p.get() {
				if tok3 != ')' {
					p.idx++
					return is_neg != test_binary(tok2, tok, tok3)
				}
			}
			p.idx--
		}
		if tok in unarys && tok2 != ')' {
			p.idx++
			return is_neg != test_unary(tok[1], tok2)
		}
	}
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

fn test_binary(option string, arg1 string, arg2 string) bool { return true }
