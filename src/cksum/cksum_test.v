import common.testing
import os

const rig = testing.prepare_rig(util: 'cksum')
const executable_under_test = rig.executable_under_test
const eol = testing.output_eol()
const test1_txt_path = os.join_path(rig.temp_dir, 'test1.txt')
const test2_txt_path = os.join_path(rig.temp_dir, 'test2.txt')
const test3_txt_path = os.join_path(rig.temp_dir, 'test3.txt')
const dummy = os.join_path(rig.temp_dir, 'dummy')
const long_over_16k = os.join_path(rig.temp_dir, 'long_over_16k')
const long_under_16k = os.join_path(rig.temp_dir, 'long_under_16k')

fn testsuite_begin() {
	rig.assert_platform_util()
	os.write_file(test1_txt_path, 'Hello World!\nHow are you?')!
	os.write_file(test2_txt_path, 'a'.repeat(128 * 1024 + 5))!
}

fn testsuite_end() {
	os.rm(test1_txt_path)!
	os.rm(test2_txt_path)!
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
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
