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
	$if windows {
		// The coreutils used on Windows does not produce the exact
		// same error messages
		rig.assert_same_exit_code('a')
		rig.assert_same_exit_code('a b')
		rig.assert_same_exit_code('a b c')
		rig.assert_same_exit_code('a b c d e f')
		os.mkdir('d')!
		rig.assert_same_exit_code('d e')
		os.rmdir('d')!
	} $else {
		rig.assert_same_results('a')
		rig.assert_same_results('a b')
		rig.assert_same_results('a b c')
		rig.assert_same_results('a b c d e f')
		os.mkdir('d')!
		rig.assert_same_results('d e')
		os.rmdir('d')!
	}

	// We can't use assert_same_results here because the hard link will already
	// exist when the second util is called
	os.write_file('a', '12345')!
	cmd1_res := rig.call_orig('a b')
	assert os.is_file('a')
	assert os.is_file('b')
	assert os.read_file('b') or { '' } == '12345'
	mut f := os.open_append('b')!
	f.write_string('67890')!
	f.close()
	assert os.read_file('a') or { '' } == '1234567890'
	os.rm('b')!
	os.rm('a')!

	os.write_file('a', '12345')!
	cmd2_res := rig.call_new('a b')
	assert os.is_file('a')
	assert os.is_file('b')
	assert os.read_file('b') or { '' } == '12345'
	f = os.open_append('b')!
	f.write_string('67890')!
	f.close()
	assert os.read_file('a') or { '' } == '1234567890'
	os.rm('b')!
	os.rm('a')!

	assert cmd1_res.exit_code == cmd2_res.exit_code
	assert testing.normalise(cmd1_res.output) == testing.normalise(cmd2_res.output)
}
