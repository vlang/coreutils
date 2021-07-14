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
			PWD := os.getenv('PWD')
			os.execute('echo $PWD')
		} else if os.args[1] == '-P' {
			println(path)
		}
	}
}
