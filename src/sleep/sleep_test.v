import os
import time
import common.testing

const util = 'sleep'

const platform_util = $if !windows {
	util
} $else {
	'coreutils ${util}'
}

const executable_under_test = testing.prepare_executable(util)

const cmd = testing.new_paired_command(platform_util, executable_under_test)

const cmd_ns = 'sleep'

fn testsuite_begin() {
	os.chdir(testing.temp_folder)!
}

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn test_unknown_option() {
	res := os.execute('${executable_under_test} -x')
	assert res.exit_code == 1
}

fn test_missing_arg() {
	assert cmd.same_results('')
}

fn test_invalid_interval() {
	assert cmd.same_results('-- -1')
	assert cmd.same_results('1a')
	assert cmd.same_results('1s0')
	assert cmd.same_results('0.01 -- -1 0.01 1a 0.01 1s0')
	res := os.execute('${executable_under_test} -1.7e+308')
	assert res.exit_code == 1
}

fn test_valid_interval() {
	assert cmd.same_results('0')
	assert cmd.same_results('0s')
	assert cmd.same_results('0.0')
	assert cmd.same_results('0.0s')
	assert cmd.same_results('0.1')
	assert cmd.same_results('0.1s')
	assert cmd.same_results('1')
	assert cmd.same_results('1s')
}

fn test_interval() {
	// 5e-7  * 86400 + 5e-7 * 3600 + 1e-4 * 60 + 1e-3 + 1e-3 = 0.053s = 53ms
	x1 := time.ticks()
	mut result_v := os.execute('${executable_under_test} 0.001 1e-3s 1e-4m 5e-7h 5e-7d')
	x2 := time.ticks()
	delta_ms := x2 - x1
	assert result_v.exit_code == 0
	// ensure there is some tolerance for CI slowness
	assert delta_ms > 1
	assert delta_ms < 80
}
