import common.testing
import os

const rig = testing.prepare_rig(util: 'date')

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_default_format() {
	res := os.execute('${rig.executable_under_test}')
	assert res.exit_code == 0
	// The default form is locale and zone dependent, so only its shape is checked:
	// a weekday, a month, a time and a year.
	assert res.output.contains('20')
	assert res.output.contains(':')
}

fn test_format_date() {
	res := os.execute('${rig.executable_under_test} +%Y-%m-%d')
	assert res.exit_code == 0
	assert res.output.len == 11
	assert res.output[4] == `-`
	assert res.output[7] == `-`
}

fn test_format_time() {
	res := os.execute('${rig.executable_under_test} +%H:%M:%S')
	assert res.exit_code == 0
	assert res.output.len == 9
	assert res.output[2] == `:`
	assert res.output[5] == `:`
}

// The format is passed without spaces because os.execute goes through the shell
// on Windows, which does not treat single quotes as quoting.
fn test_format_weekday() {
	res := os.execute('${rig.executable_under_test} +%A')
	assert res.exit_code == 0
	assert res.output.contains('day')
}

fn test_format_month() {
	res := os.execute('${rig.executable_under_test} +%B')
	assert res.exit_code == 0
	assert res.output.contains('r')
}

fn test_format_epoch() {
	res := os.execute('${rig.executable_under_test} +%s')
	assert res.exit_code == 0
	assert res.output.len >= 10
	for c in res.output.trim_space() {
		assert c >= `0` && c <= `9`
	}
}

fn test_utc() {
	res := os.execute('${rig.executable_under_test} -u +%Y-%m-%dT%H:%M:%S%z')
	assert res.exit_code == 0
	assert res.output.trim_space().ends_with('+0000')
}

fn test_rfc2822() {
	res := os.execute('${rig.executable_under_test} -R')
	assert res.exit_code == 0
	assert res.output.contains(', ')
	assert res.output.contains('20')
}

fn test_iso8601() {
	res := os.execute('${rig.executable_under_test} -I')
	assert res.exit_code == 0
	assert res.output.len == 11
	assert res.output[4] == `-`
	assert res.output[7] == `-`
}
