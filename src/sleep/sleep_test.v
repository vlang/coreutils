import common.testing
import os
import time

const rig = testing.prepare_rig(util: 'sleep')
const executable_under_test = rig.executable_under_test

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_unknown_option() {
	res := os.execute('${executable_under_test} -x')
	assert res.exit_code == 1
}

fn test_missing_arg() {
	rig.assert_same_results('')
}

fn test_invalid_interval() {
	rig.assert_same_results('-- -1')
	rig.assert_same_results('1a')
	rig.assert_same_results('1s0')
	rig.assert_same_results('0.01 -- -1 0.01 1a 0.01 1s0')
	res := os.execute('${executable_under_test} -1.7e+308')
	assert res.exit_code == 1
}

fn test_valid_interval() {
	rig.assert_same_results('0')
	rig.assert_same_results('0s')
	rig.assert_same_results('0.0')
	rig.assert_same_results('0.0s')
	rig.assert_same_results('0.1')
	rig.assert_same_results('0.1s')
	rig.assert_same_results('1')
	rig.assert_same_results('1s')
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
