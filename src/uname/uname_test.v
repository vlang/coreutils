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
	// --kernel-version is deliberately not compared. There is no kernel version on
	// Windows and the two implementations do not agree with each other about what to
	// print instead. Measured on this machine: GNU 8.32 under MSYS answers
	// "2026-04-25 10:18 UTC", uutils 0.0.17 answers "26200", which is the Windows
	// build number, and os.uname() has nothing to give at all. Comparing it byte for
	// byte would be testing the platform rather than this port.
	assert rig.call_new('--kernel-version').output.trim_space().len > 0
	rig.assert_same_results('--machine')
	/*
	rig.assert_same_results('--processor')
	rig.assert_same_results('--hardware-platform')
	rig.assert_same_results('--operating-system')*/

	// rig.assert_same_results('-a')
	// rig.assert_same_results('-ma')
	// Several short options in one argument, which is the other thing GNU has to
	// agree about. -v is left out for the reason given above.
	rig.assert_same_results('-msrn')
}
