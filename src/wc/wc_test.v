import common.testing
import os

const rig = testing.prepare_rig(util: 'wc')
const executable_under_test = rig.executable_under_test
const eol = testing.output_eol()
const file_list_sep = '\x00'
const file_list_path = os.join_path(rig.temp_dir, 'files.txt')
const test1_txt_path = os.join_path(rig.temp_dir, 'test1.txt')
const test2_txt_path = os.join_path(rig.temp_dir, 'test2.txt')
const test3_txt_path = os.join_path(rig.temp_dir, 'test3.txt')
const dummy = os.join_path(rig.temp_dir, 'dummy')
const long_over_16k = os.join_path(rig.temp_dir, 'long_over_16k')
const long_under_16k = os.join_path(rig.temp_dir, 'long_under_16k')

// todo add tests
// - test windows \r\n vs \n

fn testsuite_begin() {
	rig.assert_platform_util()
	os.chdir(testing.temp_folder)!
	os.write_file(test1_txt_path, 'Hello World!\nHow are you?')!
	os.write_file(test2_txt_path, 'twolinesonebreak\nbreakline')!
	os.write_file(test3_txt_path, 'twolinestwobreaks\nbreakline\n')!
	os.write_file(dummy, 'a'.repeat(50))!
	os.write_file(long_over_16k, 'a'.repeat(16390))!
	os.write_file(long_under_16k, 'a'.repeat(16383) + '\naaaaaaaaaaaaaaaaa')!
	os.write_file(file_list_path, '${test1_txt_path}${file_list_sep}${test2_txt_path}${file_list_sep}${test3_txt_path}')!
}

fn testsuite_end() {
	os.rm(test1_txt_path)!
	os.rm(test2_txt_path)!
	os.rm(test3_txt_path)!
	os.rm(dummy)!
	os.rm(long_over_16k)!
	os.rm(long_under_16k)!
	os.rm(file_list_path)!
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_stdin() {
	res := os.execute('cat ${test1_txt_path} | ${executable_under_test} -cmwlL')

	assert res.exit_code == 0
	assert res.output.trim_space() == '1  5 25 25 12'
}

fn test_stdin_file_list() {
	res := os.execute('cat ${file_list_path} | ${executable_under_test} -cmwlL --files0-from=-')

	assert res.exit_code == 0
	assert res.output.trim_space() == '1 5 25 25 12 ${test1_txt_path}${eol}1 2 26 26 16 ${test2_txt_path}${eol}2 2 28 28 17 ${test3_txt_path}${eol}4 9 79 79 17 total'
}

fn test_file_file_list() {
	res := os.execute('${executable_under_test} -cmwlL --files0-from=${file_list_path}')

	assert res.exit_code == 0
	assert res.output.trim_space() == '1  5 25 25 12 ${test1_txt_path}${eol} 1  2 26 26 16 ${test2_txt_path}${eol} 2  2 28 28 17 ${test3_txt_path}${eol} 4  9 79 79 17 total'
}

fn test_file_not_exist() {
	res := os.execute('${executable_under_test} abcd')

	assert res.exit_code == 1
	assert res.output.trim_space() == 'wc: abcd: No such file or directory'
}

fn test_default() {
	res := os.execute('${executable_under_test} ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == ' 1  5 25 ${test1_txt_path}${eol}'
}

fn test_max_line_length() {
	res := os.execute('${executable_under_test} -L ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == '12 ${test1_txt_path}${eol}'
}

fn test_char_count() {
	res := os.execute('${executable_under_test} -m ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == '25 ${test1_txt_path}${eol}'
}

fn test_byte_count() {
	res := os.execute('${executable_under_test} -c ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == '25 ${test1_txt_path}${eol}'
}

fn test_lines_count() {
	res := os.execute('${executable_under_test} -l ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == '1 ${test1_txt_path}${eol}'
}

fn test_words_count() {
	res := os.execute('${executable_under_test} -w ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == '5 ${test1_txt_path}${eol}'
}

fn test_one_file_all_flags() {
	res := os.execute('${executable_under_test} -cmwlL ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == ' 1  5 25 25 12 ${test1_txt_path}${eol}'
}

fn test_several_files_all_flags() {
	res := os.execute('${executable_under_test} -cmwlL ${test1_txt_path} ${test2_txt_path} ${test3_txt_path}')

	assert res.exit_code == 0
	assert res.output.trim_space() == '1  5 25 25 12 ${test1_txt_path}${eol} 1  2 26 26 16 ${test2_txt_path}${eol} 2  2 28 28 17 ${test3_txt_path}${eol} 4  9 79 79 17 total'
}

fn test_several_same_files_all_flags() {
	res := os.execute('${executable_under_test} -cmwlL ${test1_txt_path} ${test1_txt_path} ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output.trim_space() == '1  5 25 25 12 ${test1_txt_path}${eol} 1  5 25 25 12 ${test1_txt_path}${eol} 1  5 25 25 12 ${test1_txt_path}${eol} 3 15 75 75 12 total'
}

fn test_no_newline_at_end() {
	res := os.execute('${executable_under_test} -cmwlL ${dummy}')

	assert res.exit_code == 0
	assert res.output.trim_space() == '0  1 50 50 50 ${dummy}'
}

fn test_total_column_wider_than_single_file() {
	res := os.execute('${executable_under_test} -cmwlL ${dummy} ${dummy} ${dummy}')

	assert res.exit_code == 0
	assert res.output.trim_space() == '0   1  50  50  50 ${dummy}${eol}  0   1  50  50  50 ${dummy}${eol}  0   1  50  50  50 ${dummy}${eol}  0   3 150 150  50 total'
}

fn test_over_16k_line_counts_max_line() {
	res := os.execute('${executable_under_test} -cmwlL ${long_over_16k}')

	assert res.exit_code == 0
	assert res.output.trim_space() == '0     1 16390 16390 16390 ${long_over_16k}'
}

fn test_under_16k_line_counts_max_line() {
	res := os.execute('${executable_under_test} -cmwlL ${long_under_16k}')

	assert res.exit_code == 0
	assert res.output.trim_space() == '1     2 16401 16401 16383 ${long_under_16k}'
}
