import common.testing
import os

const rig = testing.prepare_rig(util: 'fold')
const executable_under_test = rig.executable_under_test
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

// The diagnostics are GNU's, and they end in a bare newline on every platform
// including Windows, so ${eol} is deliberately not used here: GNU writes "\n" and
// common.eol() is "\r\n" on this one. Measured at GNU 9.4:
//
//	fold nope1                 fold: nope1: No such file or directory   exit 1
//	fold nope1 nope2           one line each, for both files             exit 1
//	fold ok.txt nope2          the lines of ok.txt, then the error        exit 1
fn test_non_existent_file() {
	res := os.exec(testing.split_args('${executable_under_test} non-existent-file'))
	assert res.exit_code == 1
	assert res.output.trim_space() == 'fold: non-existent-file: No such file or directory'
}

fn test_non_existent_files() {
	res := os.exec(testing.split_args('${executable_under_test} non-existent-file second-non-existent-file'))
	assert res.exit_code == 1
	assert res.output.trim_space() == 'fold: non-existent-file: No such file or directory\n' +
		'fold: second-non-existent-file: No such file or directory'
}

// A file that could not be read is a failure even when another one could, and GNU
// exits 1 after printing the lines it did read.
fn test_one_missing_among_two_files() {
	res := os.execute('${executable_under_test} ${test_txt_path} non-existent-file')
	assert res.exit_code == 1
	assert res.output.contains('No such file or directory')
	assert res.output.contains('[0] Example test line')
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
	res := os.exec(testing.split_args('${executable_under_test} ${test_txt_path}'))
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
	res := os.exec(testing.split_args('${executable_under_test} ${test_txt_path} -w 10'))
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
	res := os.exec(testing.split_args('${executable_under_test} ${test_txt_path} -w 3'))
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
