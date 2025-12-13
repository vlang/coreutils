import common.testing
import os

const rig = testing.prepare_rig(util: 'dirname')
const executable_under_test = rig.executable_under_test
const slash = $if !windows {
	'\\'
} $else {
	'/'
}

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn expected_result(input string, output string) {
	res := os.execute('${executable_under_test} ${input}')
	assert res.exit_code == 0
	assert res.output.trim_space() == output
	testing.same_results('${rig.util} ${input}', '${executable_under_test} ${input}')
}

fn test_expected() {
	$if windows {
		expected_result('\\src\\expr\\foo.txt', '\\src\\expr')
		expected_result('', '.')
		expected_result('\\src\\expr\\\\.\\\\', '\\src\\expr')
		expected_result('foo.txt', '.')
	} $else {
		expected_result('/usr/bin/foo.txt', '/usr/bin')
		expected_result('', '.')
		expected_result('/usr/bin//.//', '/usr/bin')
		expected_result('foo.txt', '.')
	}
}
