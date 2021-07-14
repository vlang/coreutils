import os

fn main() {
	path := os.getwd()
	if os.user_os() == 'windows' {
		if os.args[1] == '-L' {
			os.execute('echo %cd%')
		} else if os.args[1] == '-P' {
			println(path)
		}
	} else {
		if os.args[1] == '-L' {
			pwd := os.getenv('PWD')
			println(pwd)
		} else if os.args[1] == '-P' {
			println(path)
		}
	}
}
