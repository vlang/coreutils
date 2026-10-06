import common.testing
import os

const rig = testing.prepare_rig(util: 'tee')

const input_path = 'tee_input.txt'
const out_path = 'tee_out.txt'

fn testsuite_begin() {
	os.write_file(input_path, 'line one\nline two\n')!
}

fn testsuite_end() {
	os.rm(input_path) or {}
	os.rm(out_path) or {}
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

// tee copies standard input to standard output and to every file named. The input
// is fed through a redirect, which is what a shell does for `tee < file`.
fn test_copies_to_stdout_and_file() {
	res := os.execute('${rig.executable_under_test} ${out_path} < ${input_path}')
	assert res.exit_code == 0
	assert res.output == 'line one\nline two\n'
	assert os.read_file(out_path)! == 'line one\nline two\n'
}

fn test_append_does_not_truncate() {
	os.write_file(out_path, 'existing\n')!
	res := os.execute('${rig.executable_under_test} -a ${out_path} < ${input_path}')
	assert res.exit_code == 0
	assert os.read_file(out_path)! == 'existing\nline one\nline two\n'
}

fn test_without_append_truncates() {
	os.write_file(out_path, 'existing\n')!
	res := os.execute('${rig.executable_under_test} ${out_path} < ${input_path}')
	assert res.exit_code == 0
	assert os.read_file(out_path)! == 'line one\nline two\n'
}

// A name in a directory that does not exist cannot be created, which is the case
// tee reports. A plain missing name is created by os.create and is not an error.
fn test_uncreatable_file_reports_it() {
	res := os.execute('${rig.executable_under_test} nosuchdir/out.txt < ${input_path}')
	assert res.exit_code == 1
	assert res.output.contains('nosuchdir')
}

fn test_multiple_files() {
	second := 'tee_second.txt'
	res := os.execute('${rig.executable_under_test} ${out_path} ${second} < ${input_path}')
	assert res.exit_code == 0
	assert os.read_file(out_path)! == 'line one\nline two\n'
	assert os.read_file(second)! == 'line one\nline two\n'
	os.rm(second) or {}
}
