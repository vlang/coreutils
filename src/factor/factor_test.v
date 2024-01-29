import os
import common.testing

const util = 'factor'

const platform_util = $if !windows {
	util
} $else {
	'coreutils ${util}'
}

const executable_under_test = testing.prepare_executable(util)

const cmd = testing.new_paired_command(platform_util, executable_under_test)

fn testsuite_begin() {
	os.chdir(testing.temp_folder)!
}

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn test_abcd() {
	res := os.execute('${executable_under_test} abcd')
	assert res.exit_code == 1
	assert res.output.trim_space() == 'factor: ‘abcd’ is not a valid positive integer'
}

fn expected_result(input string, output []string) {
	res := os.execute('${executable_under_test} ${input}')
	assert res.exit_code == 0
	assert res.output.split_into_lines() == output
	testing.same_results('factor ${input}', '${executable_under_test} ${input}')
}

fn test_expected() {
	expected_result('0', ['0:'])
	expected_result('1', ['1:'])
	expected_result('23', ['23: 23'])
	expected_result('45', ['45: 3 3 5'])
	expected_result('45 99', ['45: 3 3 5', '99: 3 3 11'])
}
