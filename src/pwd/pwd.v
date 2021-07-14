import os

fn main() {
	path := os.getwd()
	if os.user_os() == 'windows' {
		if os.args.len == 2 {
			if os.args[1] == '-L' {
				pwd := os.getenv('cd')
				println(pwd)
			} else if os.args[1] == '-P' {
				println(path)
			} else {
				println('unknown option')
			}
		} else {
			pwd := os.getenv('cd')
			println(pwd)
		}
	} else {
		if os.args.len == 2 {
			if os.args[1] == '-L' {
				pwd := os.getenv('PWD')
				println(pwd)
			} else if os.args[1] == '-P' {
				println(path)
			} else {
				println('unknown option')
			}
		} else {
			pwd := os.getenv('PWD')
			println(pwd)
		}
	}
}
