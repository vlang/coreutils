module pwd

import os

pub fn get_name_for_gid(gid int) !string {
	return error('Not supported on Windows')
}

pub fn get_name_for_uid(uid int) !string {
	return error('Not supported on Windows')
}

pub fn get_groups(username string) ![]int {
	return error('Not supported on Windows')
}

pub fn get_userinfo_for_name(username string) !UserInfo {
	return error('Not supported on Windows')
}

pub fn get_effective_groups() ![]int {
	return error('Not supported on Windows')
}

pub fn whoami() !string {
	username := os.loginname() or { '' }
	if username == '' {
		return error('no user name')
	}
	return username
}
