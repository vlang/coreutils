import os

const cmd_ns = 'sleep'

fn test_help() {
	result_v := os.execute('v -cg run $cmd_ns --help')
	assert result_v.exit_code == 0
}

fn test_version() {
	result_v := os.execute('v -cg run $cmd_ns --version')
	assert result_v.exit_code == 0
}

fn test_unknown_option() {
	result_v := os.execute('v -cg run $cmd_ns -x')
	assert result_v.exit_code == 1
}

fn test_missing_arg() {
	result_v := os.execute('v -cg run $cmd_ns')
	assert result_v.exit_code == 1
	assert result_v.output.contains('$cmd_ns: missing operand')
}

fn test_invalid_interval() {
	// TODO: wait for `flag` module suppurt `--'
	/*
	mut result_v := os.execute('v -cg run $cmd_ns -- -1')
	assert result_v.exit_code == 1
	assert result_v.output.contains('invalid time interval -1')
	*/

	mut result_v := os.execute('v -cg run $cmd_ns 1a')
	assert result_v.exit_code == 1
	assert result_v.output.contains('invalid time interval 1a')

	result_v = os.execute('v -cg run $cmd_ns 1s0')
	assert result_v.exit_code == 1
	assert result_v.output.contains('invalid time interval 1s0')

	// result_v = os.execute('v -cg run $cmd_ns 0.01 -- -1 0.01 1a 0.01 1s0')
	result_v = os.execute('v -cg run $cmd_ns 0.01 1a 0.01 1s0')
	assert result_v.exit_code == 1
	// assert result_v.output.contains('invalid time interval -1')
	assert result_v.output.contains('invalid time interval 1a')
	assert result_v.output.contains('invalid time interval 1s0')

	result_v = os.execute('v -cg run $cmd_ns -1.7e+308')
	assert result_v.exit_code == 1
}

fn test_interval() {
	// 5e-7  * 86400 + 5e-7 * 3600 + 1e-4 * 60 + 1e-3 + 1e-3 = 0.053
	mut result_v := os.execute('v -cg run $cmd_ns 0.001 1e-3s 1e-4m 5e-7h 5e-7d')
	assert result_v.exit_code == 0
	// debug output : ticks diff
	assert result_v.output.trim_space() in ['53', '54']
}
