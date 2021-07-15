import os

fn help() {
	println('Usage: pwd [-L | -P | -h]')
	println('Only one flag can be given at a time. If more are given it will run with -L option.')
}

fn main() {
	path := os.getwd()
	mut arg := 'null'
	if os.args.len == 2 {
		arg = os.args[1]
	}
	if os.user_os() == 'windows' {
		if os.args.len == 2 {
			if arg == '-L' {
				pwd := os.getenv('cd')
				println(pwd)
			} else if arg == '-P' {
				println(path)
			} else if arg == '-h' {
				help()
			} else {
				println('unknown option: $arg')
			}
		} else {
			pwd := os.getenv('cd')
			println(pwd)
		}
	} else {
		if os.args.len == 2 {
			if arg == '-L' {
				pwd := os.getenv('PWD')
				println(pwd)
			} else if arg == '-P' {
				println(path)
			} else if arg == '-h' {
				help()
			} else {
				println('unknown option: $arg')
			}
		} else {
			pwd := os.getenv('PWD')
			println(pwd)
		}
	}
}
