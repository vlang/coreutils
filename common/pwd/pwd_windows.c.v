module pwd

import os

pub fn whoami() !string {
	username := os.loginname() or { '' }
	if username == '' {
		return error('no user name')
	}
	return username
}
