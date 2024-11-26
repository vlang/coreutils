import common.testing
import os

const rig = testing.prepare_rig(util: 'uniq')

fn testsuite_begin() {
	rig.assert_platform_util()
	os.write_file(posix_test_path_newline, posix_test_data.join('\n'))!
	os.write_file(posix_test_path_zeroterm, posix_test_data.join('\0'))!
	os.mkdir('foo')!
}

fn testsuite_end() {
	os.rm(posix_test_path_newline)!
	os.rm(posix_test_path_zeroterm)!
	os.rmdir('foo')!
}

const posix_test_data = [
	'#01 foo0 bar0 foo1 bar1',
	'#02 bar0 foo1 bar1 foo1',
	'#03 foo0 bar0 foo1 bar1',
	'#04',
	'#05 foo0 bar0 foo1 bar1',
	'#06 foo0 bar0 foo1 bar1',
	'#07 bar0 foo1 bar1 foo0',
]
const posix_test_path_newline = 'posix_nl.txt'
const posix_test_path_zeroterm = 'posix_zt.txt'

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

fn test_source_is_directory() {
	$if !windows {
		// Due to version differences between coreutils 8.32 and 9.x,
		// this test fails on some of the CI, so we settle for same exit code.
		// rig.assert_same_results('foo')
		rig.assert_same_exit_code('foo')
	}
}

fn test_target_is_directory() {
	$if !windows {
		rig.assert_same_results('posix_nl.txt foo')
	}
}

fn test_posix_spec_case_1() {
	rig.assert_same_results('-c -f 1 posix_nl.txt')
}

fn test_posix_spec_case_2() {
	rig.assert_same_results('-d -f 1 posix_nl.txt')
}

fn test_posix_spec_case_3() {
	rig.assert_same_results('-u -f 1 posix_nl.txt')
}

fn test_posix_spec_case_4() {
	rig.assert_same_results('-d -s 2 posix_nl.txt')
}

fn test_posix_spec_case_1_zero_term() {
	assert rig.call_for_test('-c -f 1 posix_zt.txt').output.split('\0').len == 7
}

fn test_posix_spec_case_2_zero_term() {
	assert rig.call_for_test('-d -f 1 -z posix_zt.txt').output.split('\0').len == 2
}

fn test_posix_spec_case_3_zero_term() {
	assert rig.call_for_test('-u -f 1 -z posix_zt.txt').output.split('\0').len == 6
}

fn test_posix_spec_case_4_zero_term() {
	assert rig.call_for_test('-d -s 2 -z posix_zt.txt').output.split('\0').len == 1
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}
