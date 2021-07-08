import os

const cmd_ns = 'printenv'

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

fn test_print_all_default() {
	result_origin := os.execute('$cmd_ns')
	result_v := os.execute('v -cg run $cmd_ns')
	assert result_v.exit_code == result_origin.exit_code
	// TODO : resolve the issue about
	// different output order from the original printenv
	// assert result_v.output == result_origin.output
	for line in result_v.output.split('\n') {
		assert result_origin.output.contains(line) == true
	}
}

fn v_run(what string, runargs string) os.Result {
	cres := os.execute('v -cg $what')
	assert cres.exit_code == 0
	return os.execute('$what/$what $runargs')
}

fn test_print_all_nul_terminate() {
	mut result_origin := os.execute('$cmd_ns -0')
	mut result_v := v_run(cmd_ns, '-0')
	assert result_v.exit_code == result_origin.exit_code
	assert result_v.output.split_into_lines().len == result_origin.output.split_into_lines().len

	result_origin = os.execute('$cmd_ns --null')
	result_v = v_run(cmd_ns, '--null')
	assert result_v.exit_code == result_origin.exit_code
	assert result_v.output.split_into_lines().len == result_origin.output.split_into_lines().len
}

fn test_print_one_exist_env() {
	mut result_origin := os.execute('$cmd_ns LANGUAGE')
	mut result_v := os.execute('v -cg run $cmd_ns LANGUAGE')
	assert result_v.exit_code == result_origin.exit_code
	assert result_v.output == result_origin.output

	result_origin = os.execute('$cmd_ns -0 LANGUAGE')
	result_v = os.execute('v -cg run $cmd_ns -0 LANGUAGE')
	assert result_v.exit_code == result_origin.exit_code
	assert result_v.output == result_origin.output

	result_origin = os.execute('$cmd_ns LANGUAGE  -0')
	result_v = os.execute('v -cg run $cmd_ns LANGUAGE  -0')
	assert result_v.exit_code == result_origin.exit_code // 1
	assert result_v.output == result_origin.output
}

fn test_print_not_exist_env() {
	mut result_origin := os.execute('$cmd_ns xxx')
	mut result_v := os.execute('v -cg run $cmd_ns xxx')
	assert result_v.exit_code == result_origin.exit_code
	assert result_v.output == result_origin.output

	result_origin = os.execute('$cmd_ns -0 xxx')
	result_v = os.execute('v -cg run $cmd_ns -0 xxx')
	assert result_v.exit_code == result_origin.exit_code
	assert result_v.output == result_origin.output
}

fn test_print_some_env() {
	mut result_origin := os.execute('$cmd_ns LANGUAGE PWD')
	mut result_v := os.execute('v -cg run $cmd_ns LANGUAGE PWD')
	assert result_v.exit_code == result_origin.exit_code
	assert result_v.output == result_origin.output

	// TODO : resolve the issue about
	// getting different output from `os.execute`
	/*
	result_origin = os.execute('$cmd_ns -0 LANGUAGE LOGNAME')
	result_v = os.execute('v -cg run $cmd_ns -0 LANGUAGE LOGNAME')
	assert result_v.exit_code == result_origin.exit_code
	assert result_v.output == result_origin.output
	*/
}
