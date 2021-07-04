module main

import os

fn main() {
	str := match os.args.len {
		0, 1 {
			'y'
		}
		2 {
			os.args[1]
		}
		else {
			eprintln('yes: too many arguments')
			exit(1)
			''
		}
	}
	for {
		println(str)
	}
}
