import common.realpath as realpathmod
import os

fn main() {
	set := realpathmod.parse_args(os.args[1..])
	if set.operands.len == 0 {
		eprintln('realpath: missing operand')
		eprintln("Try 'realpath --help' for more information.")
		exit(1)
	}
	mut code := 0
	for operand in set.operands {
		out := realpathmod.resolve(operand, set) or {
			if err.code() != 0 {
				code = 1
			}
			if !set.quiet {
				eprintln('realpath: ${err.msg()}')
			}
			continue
		}
		if set.zero_terminated {
			print(out + u8(0).ascii_str())
		} else {
			println(out)
		}
	}
	exit(code)
}
