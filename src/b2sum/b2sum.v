import common.sums
import crypto.blake2b
import os

fn main() {
	sums.sum(os.args, 'b2sum', 'Blake2', 512, blake2b.sum512)
}
