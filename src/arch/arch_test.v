import common.testing

const executable_under_test = testing.prepare_executable('arch')

const cmd = testing.new_paired_command('arch', executable_under_test)

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
