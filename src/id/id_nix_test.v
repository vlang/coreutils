module main

import common.testing
import os

const rig = testing.prepare_rig(util: 'id')

fn testsuite_begin() {
}

fn testsuite_end() {
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_current_user() {
	compare('')
}

fn test_non_existing_users() {
	compare('does_not_exist_1 does_not_exist_2 does_not_exist_3 root does_not_exist_4')
}

fn test_all_users() {
	passwd_content := os.read_file('/etc/passwd') or {
		eprintln('Error reading /etc/passwd: ${err}')
		return
	}

	lines := passwd_content.split_into_lines()
	mut users := []string{len: lines.len}
	for line in lines {
		if line.len > 0 {
			users << line.split(':')[0]
		}
	}
	for user in users {
		compare(user)
	}
	compare(users.join(' '))
}

fn compare(user string) {
	options := 'Z g gn gr zg zgn zgr G Gn Gr zG zGn zGr n r u un ur zu zun zur uG zG Zu'
	rig.assert_same_results('')
	for opt in options.split(' ') {
		rig.assert_same_results('-${opt} ${user}')
	}
}
