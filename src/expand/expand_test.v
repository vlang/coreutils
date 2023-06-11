import os
import common.testing

const eol = testing.output_eol()

const util = 'expand'

const platform_util = $if !windows {
	util
} $else {
	'coreutils ${util}'
}

const executable_under_test = testing.prepare_executable(util)

const cmd = testing.new_paired_command(platform_util, executable_under_test)

const test_txt_path = os.join_path(testing.temp_folder, 'test.txt')

fn testsuite_begin() {
	mut f := os.open_file(test_txt_path, 'wb')!
	for l in testtxtcontent {
		f.writeln('${l}')!
	}
	f.close()
}

fn testsuite_end() {
	os.rm(test_txt_path)!
}

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn test_non_existent_file() {
	res := os.execute('${executable_under_test} non-existent-file')
	assert res.exit_code == 1
	assert res.output.trim_space() == 'expand: failed to open file "non-existent-file"'
}

const testtxtcontent = [
	'\t[0] Line with first tab',
	'[1]\tLine with second tab',
	'[2]\tLine\twith\tthree tabs',
	'[3] Line with trialing tab\t',
]

fn test_default() {
	res := os.execute('${executable_under_test} ${test_txt_path}')
	assert res.exit_code == 0
	assert res.output.split_into_lines().filter(it != '') == [
		'        [0] Line with first tab',
		'[1]        Line with second tab',
		'[2]        Line        with        three tabs',
		'[3] Line with trialing tab        ',
	]
}

fn test_initial_option() {
	res := os.execute('${executable_under_test} ${test_txt_path} -i')
	assert res.exit_code == 0
	assert res.output.split_into_lines().filter(it != '') == [
		'        [0] Line with first tab',
		'[1]\tLine with second tab',
		'[2]\tLine\twith\tthree tabs',
		'[3] Line with trialing tab\t',
	]
}

fn test_tabs_option() {
	res := os.execute('${executable_under_test} ${test_txt_path} -t 4')
	assert res.exit_code == 0
	assert res.output.split_into_lines().filter(it != '') == [
		'    [0] Line with first tab',
		'[1]    Line with second tab',
		'[2]    Line    with    three tabs',
		'[3] Line with trialing tab    ',
	]
}
