import common.testing
import os

const rig = testing.prepare_rig(util: 'fold')
const executable_under_test = rig.executable_under_test
const eol = testing.output_eol()
const test_txt_path = os.join_path(rig.temp_dir, 'test.txt')

fn testsuite_begin() {
	rig.assert_platform_util()
	mut f := os.open_file(test_txt_path, 'wb')!
	for l in testtxtcontent {
		f.writeln('${l}') or {}
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
	assert res.output.trim_space() == 'fold: failed to open file "non-existent-file"'
}

fn test_non_existent_files() {
	res := os.execute('${executable_under_test} non-existent-file second-non-existent-file')
	assert res.exit_code == 1
	assert res.output.trim_space() == 'fold: failed to open file "non-existent-file"${eol}fold: failed to open file "second-non-existent-file"'
}

const testtxtcontent = [
	'[0] Example test line',
	'[1] Example test line',
	'[2] Example test line',
	'[3] Example test line',
	'[4] Example test line',
	'[5] Example test line',
	'[6] Example test line',
	'[7] Example test line',
	'[8] Example test line',
	'[9] Example test line',
]

fn test_wrap_default() {
	res := os.execute('${executable_under_test} ${test_txt_path}')
	assert res.exit_code == 0
	assert res.output.split_into_lines().filter(it != '') == [
		'[0] Example test line',
		'[1] Example test line',
		'[2] Example test line',
		'[3] Example test line',
		'[4] Example test line',
		'[5] Example test line',
		'[6] Example test line',
		'[7] Example test line',
		'[8] Example test line',
		'[9] Example test line',
	]
}

fn test_wrap_multiline_file_with_width_10() {
	res := os.execute('${executable_under_test} ${test_txt_path} -w 10')
	assert res.exit_code == 0
	assert res.output.split_into_lines().filter(it != '') == [
		'[0] Exampl',
		'e test lin',
		'e',
		'[1] Exampl',
		'e test lin',
		'e',
		'[2] Exampl',
		'e test lin',
		'e',
		'[3] Exampl',
		'e test lin',
		'e',
		'[4] Exampl',
		'e test lin',
		'e',
		'[5] Exampl',
		'e test lin',
		'e',
		'[6] Exampl',
		'e test lin',
		'e',
		'[7] Exampl',
		'e test lin',
		'e',
		'[8] Exampl',
		'e test lin',
		'e',
		'[9] Exampl',
		'e test lin',
		'e',
	]
}

fn test_wrap_multiline_file_with_width_3() {
	res := os.execute('${executable_under_test} ${test_txt_path} -w 3')
	assert res.exit_code == 0
	assert res.output.split_into_lines().filter(it != '') == [
		'[0]',
		' Ex',
		'amp',
		'le ',
		'tes',
		't l',
		'ine',
		'[1]',
		' Ex',
		'amp',
		'le ',
		'tes',
		't l',
		'ine',
		'[2]',
		' Ex',
		'amp',
		'le ',
		'tes',
		't l',
		'ine',
		'[3]',
		' Ex',
		'amp',
		'le ',
		'tes',
		't l',
		'ine',
		'[4]',
		' Ex',
		'amp',
		'le ',
		'tes',
		't l',
		'ine',
		'[5]',
		' Ex',
		'amp',
		'le ',
		'tes',
		't l',
		'ine',
		'[6]',
		' Ex',
		'amp',
		'le ',
		'tes',
		't l',
		'ine',
		'[7]',
		' Ex',
		'amp',
		'le ',
		'tes',
		't l',
		'ine',
		'[8]',
		' Ex',
		'amp',
		'le ',
		'tes',
		't l',
		'ine',
		'[9]',
		' Ex',
		'amp',
		'le ',
		'tes',
		't l',
		'ine',
	]
}
