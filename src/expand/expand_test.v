import os
import common.testing

const rig = testing.prepare_rig(util: 'expand')
const executable_under_test = rig.executable_under_test
const eol = testing.output_eol()
const test_txt_path = os.join_path(rig.temp_dir, 'test.txt')

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
	rig.assert_help_and_version_options_work()
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
