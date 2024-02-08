import common.testing

const supported_platform = $if windows {
	false
} $else {
	true
} // WinOS lacks currently required utmp support
const rig = testing.prepare_rig(util: 'uptime', is_supported_platform: supported_platform)
const executable_under_test = rig.executable_under_test

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	if !supported_platform {
		return
	}
	rig.assert_help_and_version_options_work()
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
// 	rig.assert_same_results('')
// 	// rig.assert_same_results('/var/log/wtmp') // SKIP ~ `uptime FILE` is not universally supported
// }
