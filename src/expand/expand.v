import os
import common

fn process(line string, initial bool, tabs int) {
	mut sp := ''

	for i := tabs; i; i-- {
		sp += ' '
	}

	if initial {
		if line.starts_with('\t') {
			println(line.replace_once('\t', sp))
		} else {
			println(line)
		}
	} else {
		println(line.replace('\t', sp))
	}
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('expand')
	fp.description('convert tabs to spaces')
	initial := fp.bool('initial', `i`, false, 'do not convert tabs after non blanks')
	tabs := fp.int('tabs', `t`, 8, 'have tabs N characters apart, not 8')

	mut str_a := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}

	if str_a.len == 0 {
		for line in os.get_lines() {
			process(line, initial, tabs)
		}
	} else {
		for path in str_a {
			if path == '-' {
				for line in os.get_lines() {
					process(line, initial, tabs)
				}
			} else {
				for line in os.read_lines(path)! {
					process(line, initial, tabs)
				}
			}
		}
	}
}
