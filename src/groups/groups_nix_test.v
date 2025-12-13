import common.testing
import os

const rig = testing.prepare_rig(util: 'groups')

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_compare() {
	rig.assert_same_results('')
	rig.assert_same_results('does_not_exist')
	rig.assert_same_results('root')
	rig.assert_same_results('a b root c d')
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
		rig.assert_same_results(user)
	}
	rig.assert_same_results(users.join(' '))
}

fn test_call_errors() {
	rig.assert_same_exit_code('-x')
	rig.assert_same_results('a b c')
}
