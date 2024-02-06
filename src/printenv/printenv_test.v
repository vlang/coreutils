import common.testing

const rig = testing.prepare_rig(util: 'printenv')
const executable_under_test = rig.executable_under_test

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_unknown_option() {
	testing.command_fails('${executable_under_test} -x')!
}

fn test_print_all_default() {
	rig.assert_same_results('')
}

fn test_print_all_nul_terminate() {
	rig.assert_same_results('-0')
	rig.assert_same_results('--null')
}

fn test_print_one_exist_env() {
	rig.assert_same_results('LANGUAGE')
	rig.assert_same_results('USER')

	rig.assert_same_results('-0 LANGUAGE')
	rig.assert_same_results('LANGUAGE  -0')
}

fn test_print_not_exist_env() {
	rig.assert_same_results('xxx')
	rig.assert_same_results('-0 xxx')
}

fn test_print_several_env_variables() {
	rig.assert_same_results('LANGUAGE PWD')
	rig.assert_same_results('-0 LANGUAGE LOGNAME')
}
