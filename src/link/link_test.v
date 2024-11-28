module main

import common.testing
import os

const rig = testing.prepare_rig(util: 'link')

fn testsuite_begin() {
}

fn testsuite_end() {
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_compare() {
	rig.assert_same_results('a')
	// rig.assert_same_results('a b')
	rig.assert_same_results('a b c')
	rig.assert_same_results('a b c d e f')
	os.mkdir('d')!
	rig.assert_same_results('d e')
	os.write_file('a', '12345')!
	rig.assert_same_results('a b')
	assert os.is_file('a')
	assert os.is_file('b')
	assert os.read_file('b') or { '' } == '12345'
	mut f := os.open_append('b')!
	f.write_string('67890')!
	f.close()
	assert os.read_file('a') or { '' } == '1234567890'
	os.rm('b')!
	os.rm('a')!
}
