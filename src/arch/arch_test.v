import common.testing
import os

const util = 'arch'

const platform_util = $if !windows {
	util
} $else {
	'coreutils ${util}'
}

const executable_under_test = testing.prepare_executable(util)

const cmd = testing.new_paired_command(platform_util, executable_under_test)

fn testsuite_begin() {
	os.chdir(testing.temp_folder)!
}

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
