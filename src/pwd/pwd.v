module pwd

import os

fn help() {
	println('Usage: pwd [-L | -P | -h]')
	println('Only one flag can be given at a time. If more are given it will run with -L option.')
}

// run is the entry point shared by the standalone binary and the multicall
// binary, so both dispatch through the same code.
pub fn run(args []string) int {
	path := os.getwd()
	mut arg := 'null'
	if args.len == 2 {
		arg = args[1]
	}
	if os.user_os() == 'windows' {
		if args.len == 2 {
			if arg == '-L' {
				pwd := os.getenv('cd')
				println(pwd)
			} else if arg == '-P' {
				println(path)
			} else if arg == '-h' {
				help()
			} else {
				println('unknown option: ${arg}')
			}
		} else {
			pwd := os.getenv('cd')
			println(pwd)
		}
	} else {
		if args.len == 2 {
			if arg == '-L' {
				pwd := os.getenv('PWD')
				println(pwd)
			} else if arg == '-P' {
				println(path)
			} else if arg == '-h' {
				help()
			} else {
				println('unknown option: ${arg}')
			}
		} else {
			pwd := os.getenv('PWD')
			println(pwd)
		}
	}
	return 0
}
