module main

import common.sums
import hash.crc32
import os

fn crc_as_bytes(input []u8) []u8 {
	return crc32.sum(input).str().bytes()
}

fn main() {
	sums.sum(os.args, 'cksum', 'CRC32', 32, crc_as_bytes)
}
