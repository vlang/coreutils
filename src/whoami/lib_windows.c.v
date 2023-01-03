import os

fn whoami() !string {
	username := os.loginname()
	if username == '' {
		return error('no user name')
	}
	return username
}
