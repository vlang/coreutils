import os

fn main() {
	path := os.getwd()
	if os.user_os() == 'windows' {
		if os.args.len == 2 {
			if os.args[1] == '-L' {
				println(path)
			} else if os.args[1] == '-P' {
				os.execute('echo %cd%')
			} else {
				println('unknown option')
			}
		} else {
			println(path)
		}
	} else {
		if os.args.len == 2 {
			if os.args[1] == '-L' {
				println(path)
			} else if os.args[1] == '-P' {
				println(path)
				pwd := os.getenv('PWD')
				println(pwd)
			} else {
				println('unknown option')
			}
		} else {
			println(path)
		}
	}
}
