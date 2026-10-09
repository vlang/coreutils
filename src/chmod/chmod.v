import common.chmod as chmodmod
import os

fn main() {
	set := chmodmod.parse_args(os.args[1..])
	exit(chmodmod.run(set))
}
