import os

fn main() {
	args := os.args
	path := os.getwd()
	if os.user_os() == 'windows' {
		if args[1] == '-L' {
			os.execute('echo %cd%')
		} else if args[1] == '-P' {
			println(path)
		}
	} else {
		if args[1] == '-L' {
			os.execute('echo $PWD')
		} else if args[1] == '-P' {
			println(path)
		}
	}
}
