import common.testing

const rig = testing.prepare_rig(util: 'env')

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_compare() {
	rig.assert_same_results('')
	rig.assert_same_results('-0')
	rig.assert_same_results('-u PATH')
}
