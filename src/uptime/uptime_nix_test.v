import common.testing

const rig = testing.prepare_rig(util: 'uptime')

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_unknown_option() {
	testing.command_fails('${rig.executable_under_test} -x')!
}

// SKIP ~ comparing subsequent runs of `uptime` is a *race condition* causing random failures
// fn test_print_uptime() {
// 	if !supported_platform {
// 		return
// 	}
// 	rig.assert_same_results('')
// 	// rig.assert_same_results('/var/log/wtmp') // SKIP ~ `uptime FILE` is not universally supported
// }
