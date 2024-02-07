import common.testing

const rig = testing.prepare_rig(util: 'sync')

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_sync() {
	$if !windows {
		rig.assert_same_results('-d')
		rig.assert_same_results('-d .')
		rig.assert_same_results('-d no_such_file')
		rig.assert_same_results('-df')
		rig.assert_same_results('-f')
	}
}
