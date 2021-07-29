module main

import common.sums
import crypto.md5
import os

fn main() {
	sums.sum(os.args, 'md5sum', 'MD5', 32, md5.sum)
}
