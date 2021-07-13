import os
import common.testing

const the_executable = testing.prepare_executable('base64')

const cmd = testing.new_paired_command('base64', the_executable)

fn test_help_and_version() ? {
	cmd.ensure_help_and_version_options_work() ?
}

fn test_abcd() {
	res := os.execute('$the_executable abcd')
	assert res.exit_code == 1
	assert res.output.trim_space() == 'base64: abcd: No such file or directory'
}

fn expected_result_no_wrap(input string, output []string) {
	res := os.execute('$the_executable $input')
	assert res.exit_code == 0
	assert res.output.split_into_lines() == output
	testing.same_results('base64 -w 0 $input', '$the_executable -w 0 $input')
}

fn expected_result_default_wrap(input string, output []string) {
	res := os.execute('$the_executable $input')
	assert res.exit_code == 0
	assert res.output.split_into_lines() == output
	testing.same_results('base64 $input', '$the_executable $input')
}

fn expected_result_1_char_wrap(input string, output []string) {
	res := os.execute('$the_executable $input')
	assert res.exit_code == 0
	assert res.output.split_into_lines() == output
	testing.same_results('base64 -w 1 $input', '$the_executable -w 1 $input')
}

fn expected_result_decode(input string, output []string) {
	res := os.execute('$the_executable $input')
	assert res.exit_code == 0
	assert res.output.split_into_lines() == output
	testing.same_results('base64 $input', '$the_executable $input')
}

fn test_expected() ? {
	mut f := os.open_file('textfile', 'w') ?
	f.write_string('Hello World!\nHow are you?') ?
	f.close()

	mut g := os.open_file('base64file', 'w') ?
	g.write_string('ViBjb3JldXRpbHMgaXMgYXdlc29tZSEK') ?
	g.close()

	expected_result_no_wrap('textfile', ['SGVsbG8gV29ybGQhCkhvdyBhcmUgeW91Pw=='])
	expected_result_default_wrap('textfile', ['SGVsbG8gV29ybGQhCkhvdyBhcmUgeW91Pw=='])
	expected_result_1_char_wrap('textfile', ['SGVsbG8gV29ybGQhCkhvdyBhcmUgeW91Pw=='])
	expected_result_decode('-d base64file', ['V coreutils is awesome!'])

	os.rm('textfile') ?
	os.rm('base64file') ?
}
