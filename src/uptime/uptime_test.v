import common.testing
import os

const supported_platform = $if windows {
	false
} $else {
	true
} // WinOS lacks currently required utmp support
const rig = testing.prepare_rig(util: 'uptime', is_supported_platform: supported_platform)
const cmd = rig.cmd
const executable_under_test = rig.executable_under_test

fn testsuite_begin() {
	assert os.getwd() == rig.temp_dir
}

fn testsuite_end() {
	rig.clean_up()!
}

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
	testing.command_fails('${executable_under_test} -x')!
}

// SKIP ~ comparing subsequent runs of `uptime` is a *race condition* causing random failures
// fn test_print_uptime() {
// 	if !supported_platform {
// 		return
// 	}
// 	assert cmd.same_results('')
// 	// assert cmd.same_results('/var/log/wtmp') // SKIP ~ `uptime FILE` is not universally supported
// }
