import os
import common.testing

const the_executable = testing.prepare_executable('factor')

fn test_help() {
	res := os.execute('$the_executable --help')
	assert res.exit_code == 0
}

fn test_version() {
	res := os.execute('$the_executable --version')
	assert res.exit_code == 0
}

fn test_abcd() {
	res := os.execute('$the_executable abcd')
	assert res.exit_code == 1
	assert res.output.trim_space() == 'factor: ‘abcd’ is not a valid positive integer'
}

fn expected_result(input string, output []string) {
	res := os.execute('$the_executable $input')
	assert res.exit_code == 0
	assert res.output.split_into_lines() == output
}

fn test_expected() {
	expected_result('0', ['0: '])
	expected_result('45', ['45: 3 3 5'])
	expected_result('45 99', ['45: 3 3 5', '99: 3 3 11'])
}
