module main

import common.pr as prmod
import os

fn main() {
	set := prmod.parse_args(os.args[1..])

	// GNU emits a page header by default; -t and -h suppress it, and the
	// header carries the current date, which would make output differ from
	// run to run. A header is only printed for the default case, and only
	// when the caller has not asked to omit it.
	mut files := [][]u8{}
	for operand in set.operands {
		if operand == '-' {
			continue
		}
		if !os.exists(operand) {
			eprintln('pr: ${operand}: No such file or directory')
			exit(1)
		}
		files << os.read_file_array(operand)
	}
	println(prmod.run(set, files))
}
