module main

import common.sums
import crypto.sha1
import os

fn main() {
	sums.sum(os.args, 'sha1sum', 'SHA1', 40, sha1.sum)
}
