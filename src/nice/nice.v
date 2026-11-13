import common.nice as nicemod
import os

fn main() {
	set := nicemod.parse_args(os.args[1..])
	exit(nicemod.run(set))
}
