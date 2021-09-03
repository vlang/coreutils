module main

import common.sums
import crypto.sha256
import os

fn main() {
	sums.sum(os.args, 'sha256sum', 'SHA256', 64, sha256.sum)
}
