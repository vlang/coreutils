import common.du as dumod
import os

fn main() {
	set := dumod.parse_args(os.args[1..])
	output, failed := dumod.report(set)
	println(output)
	if failed {
		exit(1)
	}
}
