import common.install as installmod
import os

fn main() {
	set := installmod.parse_args(os.args[1..])
	exit(installmod.run(set))
}
