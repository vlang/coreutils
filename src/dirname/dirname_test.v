import common.testing
import os

const util = 'dirname'

const platform_util = $if !windows {
	util
} $else {
	'coreutils ${util}'
}

const slash = $if !windows {
	'\\'
} $else {
	'/'
}

const executable_under_test = testing.prepare_executable(util)

const cmd = testing.new_paired_command(platform_util, executable_under_test)

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn expected_result(input string, output string) {
	res := os.execute('${executable_under_test} ${input}')
	assert res.exit_code == 0
	assert res.output.trim_space() == output
	testing.same_results('dirname ${input}', '${executable_under_test} ${input}')
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
