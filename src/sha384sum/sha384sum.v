module main

import common.sums
import crypto.sha512
import os

fn main() {
	sums.sum(os.args, 'sha384sum', 'SHA384', 96, sha512.sum384)
}
