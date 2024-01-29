import os
import common.testing

const eol = testing.output_eol()
const util = 'cksum'

const platform_util = $if !windows {
	util
} $else {
	'coreutils ${util}'
}

const executable_under_test = testing.prepare_executable(util)

const cmd = testing.new_paired_command(platform_util, executable_under_test)

const temp_dir = testing.temp_folder
const test1_txt_path = os.join_path(temp_dir, 'test1.txt')
const test2_txt_path = os.join_path(temp_dir, 'test2.txt')
const test3_txt_path = os.join_path(temp_dir, 'test3.txt')
const dummy = os.join_path(temp_dir, 'dummy')
const long_over_16k = os.join_path(temp_dir, 'long_over_16k')
const long_under_16k = os.join_path(temp_dir, 'long_under_16k')

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn testsuite_begin() {
	os.write_file(test1_txt_path, 'Hello World!\nHow are you?')!
	os.write_file(test2_txt_path, 'a'.repeat(128 * 1024 + 5))!
}

fn testsuite_end() {
	os.rm(test1_txt_path)!
	os.rm(test2_txt_path)!
}

fn test_stdin() {
	res := os.execute('cat ${test1_txt_path} | ${executable_under_test}')

	assert res.exit_code == 0
	assert res.output.trim_space() == '365965416 25'
}

fn test_file_not_exist() {
	res := os.execute('${executable_under_test} abcd')

	assert res.exit_code == 1
	assert res.output.trim_space() == 'cksum: abcd: No such file or directory'
}

fn test_one_file() {
	res := os.execute('${executable_under_test} ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == '365965416 25 ${test1_txt_path}${eol}'
}

fn test_several_files() {
	res := os.execute('${executable_under_test} ${test1_txt_path} ${test2_txt_path}')

	assert res.exit_code == 0
	assert res.output == '365965416 25 ${test1_txt_path}${eol}1338884673 131077 ${test2_txt_path}${eol}'
}
