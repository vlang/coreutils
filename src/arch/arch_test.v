import common.testing

const rig = testing.prepare_rig(util: 'arch')

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_unknown_option() {
	testing.command_fails('${rig.executable_under_test} -x')!
}

fn test_redundant_argument() {
	testing.command_fails('${rig.executable_under_test} x')!
}

fn test_print_machine_arch() {
	rig.assert_same_results('')
}
