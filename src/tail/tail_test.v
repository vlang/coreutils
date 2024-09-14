module main

import os

fn setup() (fn (s string), fn () string) {
	os.chdir(os.dir(@FILE)) or { exit_error(err.msg()) }

	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	result_fn := fn [mut result_ref] () string {
		return result_ref.join('')
	}
	return out_fn, result_fn
}

fn test_lines_opt_equals_two() {
	args := Args{
		lines: 2
		files: ['test.txt']
	}
	out_fn, result_fn := setup()
	tail(args, out_fn)

	assert result_fn() == '
		02: This tool will not produce all possible combination.
		01: Output Box - Combination results will display here.'.trim_indent()
}

fn test_two_files_have_headers_separating_output() {
	args := Args{
		lines: 2
		files: ['test.txt', 'test.txt']
	}
	out_fn, result_fn := setup()
	tail(args, out_fn)

	assert result_fn() == '
		===> test.txt <===
		02: This tool will not produce all possible combination.
		01: Output Box - Combination results will display here.

		===> test.txt <===
		02: This tool will not produce all possible combination.
		01: Output Box - Combination results will display here.'.trim_indent()
}

fn test_lines_opt_equals_two_verbose() {
	args := Args{
		lines:   2
		verbose: true
		files:   ['test.txt']
	}
	out_fn, result_fn := setup()
	tail(args, out_fn)

	assert result_fn() == '
		===> test.txt <===
		02: This tool will not produce all possible combination.
		01: Output Box - Combination results will display here.'.trim_indent()
}

fn test_two_files_no_headers_quiet_option() {
	args := Args{
		lines: 2
		quiet: true
		files: ['test.txt', 'test.txt']
	}
	out_fn, result_fn := setup()
	tail(args, out_fn)

	assert result_fn() == '
		02: This tool will not produce all possible combination.
		01: Output Box - Combination results will display here.

		02: This tool will not produce all possible combination.
		01: Output Box - Combination results will display here.'.trim_indent()
}

fn test_from_start_lines() {
	args := Args{
		lines:      13
		from_start: true
		files:      ['test.txt']
	}
	out_fn, result_fn := setup()
	tail(args, out_fn)

	assert result_fn() == '
		02: This tool will not produce all possible combination.
		01: Output Box - Combination results will display here.'.trim_indent()
}

fn test_from_start_bytes() {
	args := Args{
		bytes:      666
		from_start: true
		files:      ['test.txt']
	}
	out_fn, result_fn := setup()
	tail(args, out_fn)
	assert result_fn() == '02: This tool will not produce all possible combination.\n01: Output Box - Combination results will display here.'
}
