module main

import common.testing
import common.pwd
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

fn test_current_group_order_comes_from_process_with_or_without_real_flag() {
	$if !linux {
		return
	}
	root := os.join_path(rig.temp_dir, 'group_order')
	os.mkdir_all(root)!
	defer {
		os.rmdir_all(root) or {}
	}
	fixture := os.join_path(@VMODROOT, 'src', 'id', 'testdata', 'group_order.c')
	tool := os.join_path(root, 'id')
	built := os.exec([@VEXE, '-cg', '-cflags', fixture, '-o', tool,
		os.join_path(@VMODROOT, 'src', 'id')])
	assert built.exit_code == 0, built.output
	// The C fixture makes kernel and account-database group order differ even
	// when the account running this test belongs to only one group.
	gid := os.getegid()
	process_groups := [gid, gid ^ 8, gid ^ 2, gid ^ 4]
	for options in [['-G'], ['-Gr'], ['-Gz'], ['-Grz']] {
		res := os.exec([tool, ...options])
		separator := if options[0].ends_with('z') { '\0' } else { ' ' }
		ending := if options[0].ends_with('z') { '\0' } else { '\n' }
		assert res.exit_code == 0, res.output
		assert res.output == process_groups.map(it.str()).join(separator) + ending
	}
	username := pwd.get_name_for_uid(os.getuid())!
	user := pwd.get_userinfo_for_name(username)!
	database_groups := [user.gid, user.gid ^ 4, user.gid ^ 8, user.gid ^ 2]
	for option in ['-G', '-Gr'] {
		res := os.exec([tool, option, username])
		assert res.exit_code == 0, res.output
		assert res.output == database_groups.map(it.str()).join(' ') + '\n'
	}
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
