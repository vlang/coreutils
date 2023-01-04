import common.testing

const util = 'whoami'
const platform_util = $if !windows { util } $else { "coreutils ${util}" }

const executable_under_test = testing.prepare_executable(util)

const cmd = testing.new_paired_command(platform_util, executable_under_test)

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn test_unknown_option() {
	testing.command_fails('${executable_under_test} -x')!
}

fn test_display_username() {
	assert cmd.same_results('')
}
