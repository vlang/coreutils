import os { File }
import common

const name = 'expand'
const bufsiz = 4096
const nl = '\n'

fn process_line(line string, initial bool, tabs int) {
	mut sp := ''

	for i := tabs; i; i-- {
		sp += ' '
	}

	if initial {
		if line.starts_with('\t') {
			print(line.replace_once('\t', sp))
		} else {
			print(line)
		}
	} else {
		print(line.replace('\t', sp))
	}

	if !line.ends_with(nl) {
		os.flush()
	}
}

fn process_stream(stream File, initial bool, tabs int) {
	mut buf := []u8{len: bufsiz}
	mut line := ''
	for {
		n := stream.read_bytes_with_newline(mut buf) or {
			eprintln('${name}: ${err.msg()}')
			0
		}
		if n <= 0 {
			break
		}

		unsafe {
			line += tos(buf.data, n)
		}
		if line.ends_with(nl) {
			process_line(line, initial, tabs)
			line = ''
		}
	}

	if line != '' {
		process_line(line, initial, tabs)
	}
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('expand')
	fp.description('Convert tabs to spaces')
	initial := fp.bool('initial', `i`, false, 'do not convert tabs after non blanks')
	tabs := fp.int('tabs', `t`, 8, 'have tabs N characters apart, not 8')

	mut str_a := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}

	mut streams := []File{}

	if str_a.len == 0 {
		streams << os.stdin()
	} else {
		for path in str_a {
			if path == '-' {
				streams << os.stdin()
			} else {
				streams << os.open(path) or {
					eprintln('${name}: ${err.msg()}')
					exit(1)
				}
			}
		}
	}

	for mut s in streams {
		process_stream(s, initial, tabs)
		s.close()
	}
}
