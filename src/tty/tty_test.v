import common.testing

const supported_platform = $if windows {
	false
} $else {
	true
} // No tty in Windows
const rig = testing.prepare_rig(util: 'tty', is_supported_platform: supported_platform)

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	if !supported_platform {
		return
	}
	rig.assert_help_and_version_options_work()
}

fn test_compare() {
	if !supported_platform {
		return
	}
	rig.assert_same_results('')
	rig.assert_same_results('-s')
	rig.assert_same_results('--silent')
	rig.assert_same_results('--quiet')
	rig.assert_same_results('--silent --quiet')
}
