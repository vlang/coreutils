import common.testing

const rig = testing.prepare_rig(util: 'uname')
const cmd = rig.cmd
const executable_under_test = rig.executable_under_test

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_unknown_option() {
	testing.command_fails('${executable_under_test} -x')!
	testing.command_fails('${executable_under_test} -sm -vx')!
	testing.command_fails('${executable_under_test} -sm a')!
}

fn test_print_system_info() {
	rig.assert_same_results('')
	// rig.assert_same_results('--all')
	rig.assert_same_results('--kernel-name')
	rig.assert_same_results('--nodename')
	rig.assert_same_results('--kernel-release')
	rig.assert_same_results('--kernel-version')
	rig.assert_same_results('--machine')
	/*
	rig.assert_same_results('--processor')
	rig.assert_same_results('--hardware-platform')
	rig.assert_same_results('--operating-system')*/

	// rig.assert_same_results('-a')
	// rig.assert_same_results('-ma')
	rig.assert_same_results('-vm -srn')
}
