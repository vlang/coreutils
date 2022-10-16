import os
import common.testing

const the_executable = testing.prepare_executable('wc')

const cmd = testing.new_paired_command('wc', the_executable)

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

const test_txt_path = os.join_path(testing.temp_folder, 'test.txt')

fn testsuite_begin() {
	os.write_file(test_txt_path, 'Hello World!\nHow are you?')!
}

fn testsuite_end() {
	os.rm(test_txt_path)!
}

fn test_abcd() {
	res := os.execute('$the_executable abcd')
	assert res.exit_code == 1
	assert res.output.trim_space() == 'wc: abcd: No such file or directory'
}

fn test_default() {
	res := os.execute('$the_executable $test_txt_path')
	assert res.exit_code == 0
	assert res.output == ' 1  5 25 $test_txt_path\n'
}

fn test_max_line_length() {
	res := os.execute('$the_executable -L $test_txt_path')
	assert res.exit_code == 0
	assert res.output == '12 $test_txt_path\n'
}

fn test_char_count() {
	res := os.execute('$the_executable -m $test_txt_path')
	assert res.exit_code == 0
	assert res.output == '25 $test_txt_path\n'
}
