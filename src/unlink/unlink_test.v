import common.testing
import os

const rig = testing.prepare_rig(util: 'unlink')

// TODO: The following tests fail in a Windows environment; need to
// investigate what gives.
fn test_target_does_not_exist() {
	$if !windows {
		rig.assert_same_results('does_not_exist')
	}
}

// TODO: This test does not run in all environments; to be investigated.
// fn test_too_many_operands() {
// 	$if !windows {
// 		rig.assert_same_results('a b c')
// 	}
// }

fn test_target_is_directory() {
	$if !windows {
		os.mkdir('foo')!
		rig.assert_same_results('foo')
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
	rig.assert_help_and_version_options_work()
}
