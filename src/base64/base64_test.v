import common.testing
import os

const rig = testing.prepare_rig(util: 'base64')
const executable_under_test = rig.executable_under_test

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_abcd() {
	res := os.execute('${rig.executable_under_test} abcd')
	assert res.exit_code == 1
	assert res.output.trim_space() == 'base64: abcd: No such file or directory'
}

fn expected_result(input string, output string) {
	c := '${executable_under_test} ${input}'
	res := os.execute(c)
	eprintln('>>>> cmd: `${c}`')
	if res.exit_code != 0 || res.output.split_into_lines() != output.split_into_lines() {
		eprintln('>>>> res.exit_code: ${res.exit_code}')
		eprintln('>>>> res.output   : `${res.output}`')
		eprintln('>>>> expected     : `${output}`')
	}
	assert res.exit_code == 0
	assert res.output.split_into_lines() == output.split_into_lines()
	testing.same_results('base64 ${input}', '${executable_under_test} ${input}')
}

fn test_expected() {
	os.write_file('textfile', 'Hello World!\nHow are you?')!
	os.write_file('base64file', 'ViBjb3JldXRpbHMgaXMgYXdlc29tZSEK')!
	defer {
		os.rm('textfile') or { panic(err) }
		os.rm('base64file') or { panic(err) }
	}
	expected_result('textfile', 'SGVsbG8gV29ybGQhCkhvdyBhcmUgeW91Pw==\n')
	expected_result('-w 0 textfile', 'SGVsbG8gV29ybGQhCkhvdyBhcmUgeW91Pw==')
	expected_result('-w 1 textfile', 'S\nG\nV\ns\nb\nG\n8\ng\nV\n2\n9\ny\nb\nG\nQ\nh\nC\nk\nh\nv\nd\ny\nB\nh\nc\nm\nU\ng\ne\nW\n9\n1\nP\nw\n=\n=\n')
	expected_result('-d base64file', 'V coreutils is awesome!\n')
}
