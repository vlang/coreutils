import common.testing

const rig = testing.prepare_rig(util: 'arch')
const cmd = rig.cmd
const executable_under_test = rig.executable_under_test

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn test_unknown_option() {
	testing.command_fails('${executable_under_test} -x')!
}

fn test_redundant_argument() {
	testing.command_fails('${executable_under_test} x')!
}

fn test_print_machine_arch() {
	assert cmd.same_results('')
}
