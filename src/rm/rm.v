module main

import os
import src.rm.rmutil

fn main() {
	rmutil.run_rm(os.args)
}
