import os
// Aliased: the module is called `util`, which would clash with the `util`
// constant below holding this utility's name.
import io.util as io_util
import common.testing

// GNU writes a bare LF to stdout and stderr on every platform, Windows included,
// so this is not common's eol. Measured here, each of these utilities ends its
// output with byte 10 and not with 13,10:
//
//	cksum, wc, sum, mkdir -v, head
//
// With common's eol the expectations were disagreeing by one byte per line on
// Windows, which is what the test suite has been reporting as a content difference.
const eol = '\n'
const file_sep = os.path_separator

const util = 'sum'

const platform_util = $if !windows {
	util
} $else {
	'coreutils ${util}'
}

const executable_under_test = testing.prepare_executable(util)

const cmd = testing.new_paired_command(platform_util, executable_under_test)

const test1_txt = os.join_path(testing.temp_folder, 'test1.txt')
const test2_txt = os.join_path(testing.temp_folder, 'test2.txt')
const test3_txt = os.join_path(testing.temp_folder, 'test3.txt')
const long_line = os.join_path(testing.temp_folder, 'long_line')
const large_file = os.join_path(testing.temp_folder, 'large_file')
const main_txt = os.join_path(testing.temp_folder, 'test.txt')

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

// Standard input cannot be fed from a test on Windows: the tests below say
// cat path | sum, which is a command line and not a pipe there, so the shell
// answered with exit 255. Going through cmd /c type does not work either,
// because os.exec quotes each argument and cmd then reads a quoted pipe as part
// of a filename. The ones that pass a file name still run here.
fn no_standard_input_here() bool {
	$if windows {
		println('feeding standard input from a test needs a pipe this platform has not got, skipping')
		return true
	}
	return false
}

fn testsuite_begin() {
	os.write_file(test1_txt, 'Hello World!\nHow are you?')!
	os.write_file(test2_txt, '0123456789abcdefghijklmnopqrstuvwxyz')!
	os.write_file(test3_txt, 'dummy')!
	os.write_file(long_line, 'z'.repeat(1024 * 151))!
	os.write_file(large_file, 'z'.repeat(110 * 1024 * 1024))!

	sample_file_name := @FILE.trim_right('sum_test.v') + 'test.txt'
	os.cp(sample_file_name, main_txt)!
}

fn testsuite_end() {
	os.rm(test1_txt)!
	os.rm(test2_txt)!
	os.rm(test3_txt)!
	os.rm(long_line)!
	os.rm(large_file)!
	os.rm(main_txt)!
}

/*
	tests from main branch for completeness
*/
fn test_bsd() {
	if no_standard_input_here() {
		return
	}
	res := os.exec(testing.split_args('cat ${main_txt} | ${executable_under_test} -r'))

	assert res.exit_code == 0
	assert res.output == '38039     1${eol}'
}

fn test_sysv() {
	if no_standard_input_here() {
		return
	}
	res := os.exec(testing.split_args('cat ${main_txt} | ${executable_under_test} -s'))

	assert res.exit_code == 0
	assert res.output == '25426 1${eol}'
}

/*
	test main SysV switch behavior
*/
fn test_sysv_stream_succeeds() {
	if no_standard_input_here() {
		return
	}
	res := os.exec(testing.split_args('cat ${test1_txt} | ${executable_under_test} -s'))

	assert res.exit_code == 0
	assert res.output == '2185 1${eol}'
}

fn test_sysv_one_file_succeeds() {
	res := os.exec(testing.split_args('${executable_under_test} -s ${test1_txt}'))

	assert res.exit_code == 0
	assert res.output == '2185 1 ${test1_txt}${eol}'
}

fn test_sysv_repeated_files_not_get_filtered() {
	res := os.exec(testing.split_args('${executable_under_test} -s ${test1_txt} ${test1_txt} ${test1_txt}'))

	assert res.exit_code == 0
	assert res.output == '2185 1 ${test1_txt}${eol}2185 1 ${test1_txt}${eol}2185 1 ${test1_txt}${eol}'
}

fn test_sysv_several_files_succeeds() {
	res := os.exec(testing.split_args('${executable_under_test} -s ${test1_txt} ${test2_txt} ${test3_txt}'))

	assert res.exit_code == 0
	assert res.output == '2185 1 ${test1_txt}${eol}3372 1 ${test2_txt}${eol}556 1 ${test3_txt}${eol}'
}

fn sum_arbitrary_value(value string, arg string) !os.Result {
	// Every caller of this needs a pipe, so it is answered here rather than in eight
	// places.
	if no_standard_input_here() {
		return error('standard input is not reachable from a test here')
	}
	mut f, path := io_util.temp_file()!
	f.write_string('${value}\n')!
	f.close()
	res := $if windows {
		os.exec(testing.split_args("cat ${path} | tr -d '\\r' | ${executable_under_test} ${arg}"))
	} $else {
		os.exec(testing.split_args('cat ${path} | ${executable_under_test} ${arg}'))
	}
	os.rm(path)!
	return res
}

/*
	test SysV output quirks
*/
fn test_sysv_width_2_col_no_padding() {
	res := sum_arbitrary_value('', '-s') or { return }

	assert res.exit_code == 0
	assert res.output == '10 1${eol}'
}

fn test_sysv_width_3_col_no_padding() {
	res := sum_arbitrary_value('\x61', '-s') or { return }

	assert res.exit_code == 0
	assert res.output == '107 1${eol}'
}

fn test_sysv_width_4_col_no_padding() {
	res := sum_arbitrary_value('zzzzzzzzz', '-s') or { return }

	assert res.exit_code == 0
	assert res.output == '1108 1${eol}'
}

fn test_sysv_different_col_widths_no_alignment() {
	res :=
		os.exec(testing.split_args('${executable_under_test} -s ${long_line} ${test1_txt} ${test2_txt} ${test3_txt}'))

	assert res.exit_code == 0
	assert res.output == '55583 302 ${long_line}${eol}2185 1 ${test1_txt}${eol}3372 1 ${test2_txt}${eol}556 1 ${test3_txt}${eol}'
}

/*
	test main BSD switch behavior
*/
fn test_bsd_sum_stream_succeeds() {
	if no_standard_input_here() {
		return
	}
	res := os.exec(testing.split_args('cat ${test1_txt} | ${executable_under_test} -r'))

	assert res.exit_code == 0
	assert res.output == '59852     1${eol}'
}

fn test_bsd_sum_one_file_succeeds() {
	res := os.exec(testing.split_args('${executable_under_test} -r ${test1_txt}'))

	assert res.exit_code == 0
	assert res.output == '59852     1${eol}'
}

fn test_bsd_sum_repeated_files_not_get_filtered() {
	res := os.exec(testing.split_args('${executable_under_test} -r ${test1_txt} ${test1_txt} ${test1_txt}'))

	assert res.exit_code == 0
	assert res.output == '59852     1 ${test1_txt}${eol}59852     1 ${test1_txt}${eol}59852     1 ${test1_txt}${eol}'
}

fn test_bsd_sum_several_files_succeeds() {
	res := os.exec(testing.split_args('${executable_under_test} -r ${test1_txt} ${test2_txt} ${test3_txt}'))

	assert res.exit_code == 0
	assert res.output == '59852     1 ${test1_txt}${eol}11628     1 ${test2_txt}${eol}41183     1 ${test3_txt}${eol}'
}

/*
	test BSD output quirks
*/
fn test_bsd_sum_col_width_2_padded_with_zero() {
	res := sum_arbitrary_value('\x02', '-r') or { return }

	assert res.exit_code == 0
	assert res.output == '00011     1${eol}'
}

fn test_bsd_sum_col_width_3_padded_with_zero() {
	res := sum_arbitrary_value('hhh', '-r') or { return }

	assert res.exit_code == 0
	assert res.output == '00101     1${eol}'
}

fn test_bsd_sum_col_width_4_padded_with_zero() {
	res := sum_arbitrary_value('hhh', '-r') or { return }

	assert res.exit_code == 0
	assert res.output == '00101     1${eol}'
}

fn test_bsd_block_col_width_more_than_5_not_aligned() {
	// this test needs 100+MB input string and since there's no easy way to mock block count fn,
	// we need to create an actual file
	res := os.exec(testing.split_args('${executable_under_test} -r ${test1_txt} ${large_file} ${test2_txt}'))
	assert res.exit_code == 0
	assert res.output == '59852     1 ${test1_txt}${eol}62707 112640 ${large_file}${eol}11628     1 ${test2_txt}${eol}'
}
