import common.testing

const rig = testing.prepare_rig(util: 'printenv')
const cmd = rig.cmd
const executable_under_test = rig.executable_under_test

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn test_unknown_option() {
	testing.command_fails('${executable_under_test} -x')!
}

fn test_print_all_default() {
	assert cmd.same_results('')
}

fn test_print_all_nul_terminate() {
	assert cmd.same_results('-0')
	assert cmd.same_results('--null')
}

fn test_print_one_exist_env() {
	assert cmd.same_results('LANGUAGE')
	assert cmd.same_results('USER')

	assert cmd.same_results('-0 LANGUAGE')
	assert cmd.same_results('LANGUAGE  -0')
}

fn test_print_not_exist_env() {
	assert cmd.same_results('xxx')
	assert cmd.same_results('-0 xxx')
}

fn test_print_several_env_variables() {
	assert cmd.same_results('LANGUAGE PWD')
	assert cmd.same_results('-0 LANGUAGE LOGNAME')
}
