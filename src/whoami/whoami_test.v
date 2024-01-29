import common.testing
import os

const rig = testing.prepare_rig('whoami')
const cmd = rig.cmd

fn testsuite_begin() {
	assert os.getwd() == rig.temp_dir
}

fn testsuite_end() {
	rig.clean_up()!
}

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn test_unknown_option() {
	testing.command_fails('${rig.executable_under_test} -x')!
}

fn test_display_username() {
	assert cmd.same_results('')
}
