import common.df as dfmod
import os

fn main() {
	set := dfmod.parse_args(os.args[1..])
	output := dfmod.report(set) or {
		eprintln('df: ${err.msg()}')
		exit(1)
	}
	println(output)
}
