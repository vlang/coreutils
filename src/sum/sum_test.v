import os

import common.testing

const eol = testing.output_eol()
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

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn testsuite_begin() {
	os.write_file(test1_txt, 'Hello World!\nHow are you?')!
	os.write_file(test2_txt, '0123456789abcdefghijklmnopqrstuvwxyz')!
	os.write_file(test3_txt, 'dummy')!
	os.write_file(long_line, 'z'.repeat(1024 * 151))!
	os.write_file(large_file, 'z'.repeat(110 * 1024 * 1024))!
}

fn testsuite_end() {
	os.rm(test1_txt)!
	os.rm(test2_txt)!
	os.rm(test3_txt)!
	os.rm(long_line)!
	os.rm(large_file)!
}

/*
	test main SysV switch behavior
*/
fn test_sysv_stream_succeeds() {
	res := os.execute('cat ${test1_txt} | ${executable_under_test} -s')

	assert res.exit_code == 0
	assert res.output == '2185 1${eol}'
}

fn test_sysv_one_file_succeeds() {
	res := os.execute('${executable_under_test} -s ${test1_txt}')

	assert res.exit_code == 0
	assert res.output == '2185 1 ${test1_txt}${eol}'
}

fn test_sysv_repeated_files_not_get_filtered() {
	res := os.execute('${executable_under_test} -s ${test1_txt} ${test1_txt} ${test1_txt}')

	assert res.exit_code == 0
	assert res.output == '2185 1 ${test1_txt}${eol}2185 1 ${test1_txt}${eol}2185 1 ${test1_txt}${eol}'
}

fn test_sysv_several_files_succeeds() {
	res := os.execute('${executable_under_test} -s ${test1_txt} ${test2_txt} ${test3_txt}')

	assert res.exit_code == 0
	assert res.output == '2185 1 ${test1_txt}${eol}3372 1 ${test2_txt}${eol}556 1 ${test3_txt}${eol}'
}

/*
	test SysV output quirks
*/
fn test_sysv_width_2_col_no_padding() {
	res := os.execute('echo \x09 | ${executable_under_test} -s')

	assert res.exit_code == 0
	assert res.output == '10 1${eol}'
}

fn test_sysv_width_3_col_no_padding() {
	res := os.execute('echo \x61 | ${executable_under_test} -s')

	assert res.exit_code == 0
	assert res.output == '107 1${eol}'
}

fn test_sysv_width_4_col_no_padding() {
	res := os.execute('echo zzzzzzzzz | ${executable_under_test} -s')

	assert res.exit_code == 0
	assert res.output == '1108 1${eol}'
}

fn test_sysv_different_col_widths_no_alignment() {
	res := os.execute('${executable_under_test} -s ${long_line} ${test1_txt} ${test2_txt} ${test3_txt}')

	assert res.exit_code == 0
	assert res.output == '55583 302 ${long_line}${eol}2185 1 ${test1_txt}${eol}3372 1 ${test2_txt}${eol}556 1 ${test3_txt}${eol}'
}

/*
	test main BSD switch behavior
*/
fn test_bsd_sum_stream_succeeds() {
	res := os.execute('cat ${test1_txt} | ${executable_under_test} -r')

	assert res.exit_code == 0
	assert res.output == '59852     1${eol}'
}

fn test_bsd_sum_one_file_succeeds() {
	res := os.execute('${executable_under_test} -r ${test1_txt}')

	assert res.exit_code == 0
	assert res.output == '59852     1${eol}'
}

fn test_bsd_sum_repeated_files_not_get_filtered() {
	res := os.execute('${executable_under_test} -r ${test1_txt} ${test1_txt} ${test1_txt}')

	assert res.exit_code == 0
	assert res.output == '59852     1 ${test1_txt}${eol}59852     1 ${test1_txt}${eol}59852     1 ${test1_txt}${eol}'
}

fn test_bsd_sum_several_files_succeeds() {
	res := os.execute('${executable_under_test} -r ${test1_txt} ${test2_txt} ${test3_txt}')

	assert res.exit_code == 0
	assert res.output == '59852     1 ${test1_txt}${eol}11628     1 ${test2_txt}${eol}41183     1 ${test3_txt}${eol}'
}

/*
	test BSD output quirks
*/
fn test_bsd_sum_col_width_2_padded_with_zero() {
	res := os.execute('echo \x02 | ${executable_under_test} -r')

	assert res.exit_code == 0
	assert res.output == '00011     1${eol}'
}

fn test_bsd_sum_col_width_3_padded_with_zero() {
	res := os.execute('echo hhh | ${executable_under_test} -r')

	assert res.exit_code == 0
	assert res.output == '00101     1${eol}'
}

fn test_bsd_sum_col_width_4_padded_with_zero() {
	res := os.execute('echo hhh | ${executable_under_test} -r')

	assert res.exit_code == 0
	assert res.output == '00101     1${eol}'
}

fn test_bsd_block_col_width_more_than_5_not_aligned() {
	// this test needs 100+MB input string and since there's no easy way to mock block count fn,
	// we need to create an actual file
	res := os.execute('${executable_under_test} -r ${test1_txt} ${large_file} ${test2_txt}')

	assert res.exit_code == 0
	assert res.output == '59852     1 ${test1_txt}${eol}62707 112640 ${large_file}${eol}11628     1 ${test2_txt}${eol}'
}
