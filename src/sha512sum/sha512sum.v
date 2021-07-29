module main

import common.sums
import crypto.sha512
import os

fn main() {
	sums.sum(os.args, 'sha512sum', 'SHA512', 128, sha512.sum512)
}
