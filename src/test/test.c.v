module main

import os
import strconv

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
	return if args[1] in binarys {
		test_binary(args[1], args[0], args[2])
	} else if args[0] == '!' {
		!two_args(args[1..])
	} else if args[1] == '-a' {
		args[0] != '' && args[2] != ''
	} else if args[1] == '-o' {
		args[0] != '' || args[2] != ''
	} else if args[0] == '(' {
		if args[2] != ')' {
			my_panic('expect `)`')
			false // v magic
		} else {
			args[1] != ''
		}
	} else {
		my_panic('expect binary operator')
		false // v magic
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
	mut tok := p.get() or { return b }
	for tok == '-o' {
		p.idx++
		b = b || p.and()
		tok = p.get() or { return b }
	}
	return b
}

fn (mut p Parser) and() bool {
	mut b := p.term()
	mut tok := p.get() or { return b }
	for tok == '-a' {
		p.idx++
		b = b && p.term()
		tok = p.get() or { return b }
	}
	return b
}

fn (mut p Parser) term() bool {
	mut is_neg := false
	mut tok := p.get() or { my_panic('expect expression after `${p.tokens[p.idx - 1]}`') }
	for tok == '!' {
		is_neg = !is_neg
		p.idx++
		tok = p.get() or { my_panic('expect expression after `!`') }
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
	if tok == '-l' {
		tok2 := p.get() or { my_panic('expect string') }
		tok = tok2.len.str()
		p.idx++
	}
	if tok2 := p.get() {
		if tok2 in binarys {
			p.idx++
			if _tok3 := p.get() {
				mut tok3 := _tok3
				if tok3 != ')' {
					p.idx++
					if tok3 == '-l' {
						tok4 := p.get() or { my_panic('expect string') }
						tok3 = tok4.len.str()
						p.idx++
					}
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
	if tok == '-t' {
		return is_neg != test_unary(`t`, '1')
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

fn test_unary(option byte, arg string) bool {
	match option {
		`b` {
			return os.exists(arg) && FileType(os.inode(arg).typ) == .block_device
		}
		`c` {
			return os.exists(arg) && FileType(os.inode(arg).typ) == .character_device
		}
		`d` {
			return os.is_dir(arg)
		}
		`e` {
			return os.exists(arg)
		}
		`f` {
			return os.is_file(arg)
		}
		`g` {
			if !os.exists(arg) {
				return false
			}
			attr := C.stat{}
			unsafe {
				C.stat(&char(arg.str), &attr)
			}
			return attr.st_mode & os.s_isgid > 0
		}
		`h`, `L` {
			return os.is_link(arg)
		}
		`n` {
			return arg.len != 0
		}
		`p` {
			return os.exists(arg) && FileType(os.inode(arg).typ) == .fifo
		}
		`r` {
			return os.is_readable(arg)
		}
		`S` {
			return os.exists(arg) && FileType(os.inode(arg).typ) == .socket
		}
		`s` {
			return os.file_size(arg) > 0
		}
		`t` {
			return os.is_atty(arg.int()) == 1
		}
		`u` {
			if !os.exists(arg) {
				return false
			}
			attr := C.stat{}
			unsafe {
				C.stat(&char(arg.str), &attr)
			}
			return attr.st_mode & os.s_isuid > 0
		}
		`w` {
			return os.is_writable(arg)
		}
		`x` {
			return os.is_executable(arg)
		}
		`z` {
			return arg.len == 0
		}
		else {}
	}
	my_panic('unexpected unary operator')
}

struct C.stat {
	st_size  u64
	st_mode  u32
	st_mtime int
	st_dev   usize
	st_ino   usize
}

enum FileType {
	regular
	directory
	character_device
	block_device
	fifo
	symbolic_link
	socket
}

fn test_binary(option string, arg1 string, arg2 string) bool {
	match option {
		'=', '==' {
			return arg1 == arg2
		}
		'!=' {
			return arg1 != arg2
		}
		'-eq' {
			left := strconv.parse_int(arg1, 0, 64) or { my_panic('expect integer') }
			right := strconv.parse_int(arg2, 0, 64) or { my_panic('expect integer') }
			return left == right
		}
		'-ne' {
			left := strconv.parse_int(arg1, 0, 64) or { my_panic('expect integer') }
			right := strconv.parse_int(arg2, 0, 64) or { my_panic('expect integer') }
			return left != right
		}
		'-gt' {
			left := strconv.parse_int(arg1, 0, 64) or { my_panic('expect integer') }
			right := strconv.parse_int(arg2, 0, 64) or { my_panic('expect integer') }
			return left > right
		}
		'-ge' {
			left := strconv.parse_int(arg1, 0, 64) or { my_panic('expect integer') }
			right := strconv.parse_int(arg2, 0, 64) or { my_panic('expect integer') }
			return left >= right
		}
		'-lt' {
			left := strconv.parse_int(arg1, 0, 64) or { my_panic('expect integer') }
			right := strconv.parse_int(arg2, 0, 64) or { my_panic('expect integer') }
			return left < right
		}
		'-le' {
			left := strconv.parse_int(arg1, 0, 64) or { my_panic('expect integer') }
			right := strconv.parse_int(arg2, 0, 64) or { my_panic('expect integer') }
			return left <= right
		}
		'-nt' {
			if !os.exists(arg1) || !os.exists(arg2) {
				return false
			}
			return os.file_last_mod_unix(arg1) > os.file_last_mod_unix(arg2)
		}
		'-ot' {
			if !os.exists(arg1) || !os.exists(arg2) {
				return false
			}
			return os.file_last_mod_unix(arg1) < os.file_last_mod_unix(arg2)
		}
		'-ef' {
			if !os.exists(arg1) || !os.exists(arg2) {
				return false
			}
			attr1 := C.stat{}
			attr2 := C.stat{}
			unsafe {
				C.stat(&char(arg1.str), &attr1)
				C.stat(&char(arg2.str), &attr2)
			}
			return attr1.st_dev == attr2.st_dev && attr1.st_ino == attr2.st_ino
		}
		else {
			my_panic('unexpected binary operator')
		}
	}
}
