module main

import common.sums
import crypto.sha256
import os

fn main() {
	sums.sum(os.args, 'sha224sum', 'SHA224', 56, sha256.sum224)
}
