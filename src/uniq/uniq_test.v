import common.testing
import os

const util = 'uniq'
const platform_util = $if !windows {
	util
} $else {
	'coreutils ${util}'
}

const cmd = testing.new_paired_command(platform_util, executable_under_test)
const executable_under_test = testing.prepare_executable(util)
const temp_dir = testing.temp_folder

const posix_test_data = [
	'#01 foo0 bar0 foo1 bar1',
	'#02 bar0 foo1 bar1 foo1',
	'#03 foo0 bar0 foo1 bar1',
	'#04',
	'#05 foo0 bar0 foo1 bar1',
	'#06 foo0 bar0 foo1 bar1',
	'#07 bar0 foo1 bar1 foo0',
]
const posix_test_path_newline = '${util}_posix_nl.txt'
const posix_test_path_zeroterm = '${util}_posix_zt.txt'

fn call_for_test(args string) os.Result {
	res := os.execute('${executable_under_test} ${args}')
	assert res.exit_code == 0
	return res
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

fn test_source_is_directory() {
	$if !windows {
		assert cmd.same_results('${util}_foo')
	}
}

fn test_target_is_directory() {
	$if !windows {
		assert cmd.same_results('${posix_test_path_newline} ${util}_foo')
	}
}

fn test_posix_spec_case_1() {
	assert cmd.same_results('-c -f 1 ${posix_test_path_newline}')
}

fn test_posix_spec_case_2() {
	assert cmd.same_results('-d -f 1 ${posix_test_path_newline}')
}

fn test_posix_spec_case_3() {
	assert cmd.same_results('-u -f 1 ${posix_test_path_newline}')
}

fn test_posix_spec_case_4() {
	assert cmd.same_results('-d -s 2 ${posix_test_path_newline}')
}

fn test_posix_spec_case_1_zero_term() {
	assert call_for_test('-c -f 1 ${posix_test_path_zeroterm}').output.split('\0').len == 7
}

fn test_posix_spec_case_2_zero_term() {
	assert call_for_test('-d -f 1 -z ${posix_test_path_zeroterm}').output.split('\0').len == 2
}

fn test_posix_spec_case_3_zero_term() {
	assert call_for_test('-u -f 1 -z ${posix_test_path_zeroterm}').output.split('\0').len == 6
}

fn test_posix_spec_case_4_zero_term() {
	assert call_for_test('-d -s 2 -z ${posix_test_path_zeroterm}').output.split('\0').len == 1
}

fn testsuite_begin() {
	os.chdir(testing.temp_folder)!
	os.write_file(posix_test_path_newline, posix_test_data.join('\n'))!
	os.write_file(posix_test_path_zeroterm, posix_test_data.join('\0'))!
	os.mkdir('${util}_foo')!
}

fn testsuite_end() {
	os.rmdir('${util}_foo')!
	os.rm(posix_test_path_newline)!
	os.rm(posix_test_path_zeroterm)!
}

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}
