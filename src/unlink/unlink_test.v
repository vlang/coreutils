import common.testing
import os

const util = 'unlink'
const platform_util = $if !windows {
	util
} $else {
	'coreutils ${util}'
}

const cmd = testing.new_paired_command(platform_util, executable_under_test)
const executable_under_test = testing.prepare_executable(util)
const temp_dir = testing.temp_folder

fn call_for_test(args string) os.Result {
	res := os.execute('${executable_under_test} ${args}')
	assert res.exit_code == 0
	return res
}

fn testsuite_begin() {
	os.chdir(testing.temp_folder)!
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
	call_for_test('a')
	assert !os.is_file('a')
}

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}
