import common.testing

const util = 'whoami'

const supported_platform = $if windows {
	false
} $else {
	true
} // WinOS lacks currently required utmp support

const the_executable = if supported_platform {
	testing.prepare_executable(util)
} else {
	''
}

const cmd = testing.new_paired_command(util, the_executable)

fn test_help_and_version() {
	if !supported_platform {
		return
	}
	cmd.ensure_help_and_version_options_work()!
}

fn test_unknown_option() {
	if !supported_platform {
		return
	}
	testing.command_fails('${the_executable} -x')!
}

fn test_print_machine_arch() {
	if !supported_platform {
		return
	}
	assert cmd.same_results('')
}
