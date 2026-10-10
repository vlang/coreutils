import common.dir as dirmod
import os

fn main() {
	set := dirmod.parse_args(os.args[1..])
	output, code := dirmod.run(set)
	if output != '' {
		println(output)
	}
	exit(code)
}
