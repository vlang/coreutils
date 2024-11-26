module main

import common.testing

const rig = testing.prepare_rig(util: 'id')

fn testsuite_begin() {
}

fn testsuite_end() {
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_compare() {
	rig.assert_same_results('-Z')
	rig.assert_same_results('-g')
	rig.assert_same_results('-G')
	rig.assert_same_results('-n')
	rig.assert_same_results('-r')
	rig.assert_same_results('-u')
	rig.assert_same_results('-uG')
	rig.assert_same_results('-zG')
}
