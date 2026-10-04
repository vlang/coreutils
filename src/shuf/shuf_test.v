import common.testing
import os

const rig = testing.prepare_rig(util: 'shuf')
const executable_under_test = rig.executable_under_test
// GNU writes a bare LF to stdout and stderr on every platform, Windows included,
// so this is not common's eol. Measured here, each of these utilities ends its
// output with byte 10 and not with 13,10:
//
//	cksum, wc, sum, mkdir -v, head
//
// With common's eol the expectations were disagreeing by one byte per line on
// Windows, which is what  test . has been reporting as a content difference.
const eol = '\n'
const test_txt_path = os.join_path(rig.temp_dir, 'test.txt')

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_echo() {
	res := os.execute('${executable_under_test} -e aa bb')
	assert res.output == 'aa${eol}bb${eol}' || res.output == 'bb${eol}aa${eol}'
}

fn test_file() {
	os.write_file(test_txt_path, 'hello\nworld!')!
	res := os.execute('${executable_under_test} ${test_txt_path}')
	assert res.output == 'hello${eol}world!${eol}' || res.output == 'world!${eol}hello${eol}'
}

fn test_zero_terminated_echo() {
	os.write_file(test_txt_path, 'hello\nworld!')!
	rig.assert_same_results('-z -e --random-source ${test_txt_path} aa bb')
}

fn test_zero_terminated_file() {
	os.write_file(test_txt_path, 'aa\x00bb\x00')!
	rig.assert_same_results('-z --random-source ${test_txt_path} ${test_txt_path}')
}

fn test_head_count() {
	res := os.execute('${executable_under_test} -n 5 -i 1-10')
	println(res.output.split_into_lines())
	assert res.output.split_into_lines().len == 5
}

fn test_input_range() {
	res := os.execute('${executable_under_test} -i 1-10')
	assert res.output.split_into_lines().len == 10
}

// The permutation produced by a given --random-source file is fully
// determined, so it is compared against the platform shuf rather than being
// hardcoded: the exact sequence of bytes consumed changed between GNU 8.32 and
// later releases, and the platform utility is the reference this test rig
// already trusts everywhere else.
fn test_random_source() {
	os.write_file(test_txt_path, 'hello\nworld!')!
	rig.assert_same_results('-i 1-5 --random-source ${test_txt_path}')
}

fn test_random_source_lines() {
	os.write_file(test_txt_path, 'a\nb\nc\nd\ne\n')!
	rig.assert_same_results('--random-source ${test_txt_path} ${test_txt_path}')
}

fn test_random_source_head_count() {
	os.write_file(test_txt_path, 'a\nb\nc\nd\ne\n')!
	rig.assert_same_results('-n 3 --random-source ${test_txt_path} ${test_txt_path}')
}

fn test_random_source_exhausted() {
	os.write_file(test_txt_path, 'hello\nworld!')!
	// Only the exit status is compared: common.exit_with_error_message adds a
	// "Try 'shuf --help'" line that GNU does not print.
	rig.cmd.expected_failure('-i 1-1000 --random-source ${test_txt_path}')!
}

fn test_random_source_missing_file() {
	rig.cmd.expected_failure('-i 1-5 --random-source ${rig.temp_dir}/no-such-source')!
}

fn test_repeat_with_random_source() {
	rig.assert_same_results('-r -n 6 -e --random-source ${test_txt_path} aa bb')
}

// Empty lines are part of the input; the previous implementation dropped them.
fn test_empty_lines_are_kept() {
	os.write_file(test_txt_path, 'x\n\ny\n')!
	rig.assert_same_results('--random-source ${test_txt_path} ${test_txt_path}')
}

fn test_output_file_matches() {
	os.write_file(test_txt_path, 'hello\nworld!')!
	rig.call_new('-i 1-5 --random-source ${test_txt_path} -o out1')
	rig.call_orig('-i 1-5 --random-source ${test_txt_path} -o out2')
	assert os.read_file('out1')! == os.read_file('out2')!
	os.rm('out1')!
	os.rm('out2')!
}

fn test_head_count_zero_outputs_nothing() {
	os.write_file(test_txt_path, 'a\nb\nc\n')!
	res := os.execute('${executable_under_test} -n 0 ${test_txt_path}')
	assert res.exit_code == 0
	assert res.output == ''
}

fn test_input_range_errors() {
	for bad in ['5-1', 'abc', '1-x', '-', '1-2-3'] {
		rig.cmd.expected_failure('-i ${bad}')!
	}
}

fn test_extra_operand() {
	rig.cmd.expected_failure('a b')!
}

fn test_echo_and_input_range_conflict() {
	rig.cmd.expected_failure('-e -i 1-5')!
}

fn test_unknown_option() ? {
	res := os.execute('${executable_under_test} -x')
	assert res.exit_code == 1
}
