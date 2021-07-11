import os
import common.testing

const the_executable = testing.prepare_executable('factor')

const cmd = testing.new_paired_command('factor', the_executable)

fn test_help_and_version() ? {
	cmd.ensure_help_and_version_options_work() ?
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
	testing.same_results('factor $input', '$the_executable $input')
}

fn test_expected() {
	expected_result('0', ['0:'])
	expected_result('1', ['1:'])
	expected_result('23', ['23: 23'])
	expected_result('45', ['45: 3 3 5'])
	expected_result('45 99', ['45: 3 3 5', '99: 3 3 11'])
}
