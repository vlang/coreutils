import common.testing
import os

const rig = testing.prepare_rig(util: 'factor')
const executable_under_test = rig.executable_under_test

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
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
	testing.same_results('${rig.util} ${input}', '${executable_under_test} ${input}')
}

fn test_expected() {
	expected_result('0', ['0:'])
	expected_result('1', ['1:'])
	expected_result('23', ['23: 23'])
	expected_result('45', ['45: 3 3 5'])
	expected_result('45 99', ['45: 3 3 5', '99: 3 3 11'])
}
