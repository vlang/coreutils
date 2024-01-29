import common.testing
import os

const rig = testing.prepare_rig('unlink')
const cmd = rig.cmd

fn testsuite_begin() {
	assert os.getwd() == rig.temp_dir
}

fn testsuite_end() {
	rig.clean_up()!
}

// TODO: The following tests fail in a Windows environment; need to
// investigate what gives.
fn test_target_does_not_exist() {
	$if !windows {
		assert cmd.same_results('does_not_exist')
	}
}

// TODO: This test does not run in all environments; to be investigated.
// fn test_too_many_operands() {
// 	$if !windows {
// 		assert cmd.same_results('a b c')
// 	}
// }

fn test_target_is_directory() {
	$if !windows {
		os.mkdir('foo')!
		assert cmd.same_results('foo')
		os.rmdir('foo')!
	}
}

fn test_target_does_exist() {
	// Unfortunately, we cannot do a same_results comparison since
	// the first call will blow away the target
	os.write_file('a', '')!
	assert os.is_file('a')
	rig.call_for_test('a')
	assert !os.is_file('a')
}

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}
