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

fn expected_result(input string, output string) {
	res := os.execute('$the_executable $input')
	assert res.exit_code == 0
	assert res.output == output
	testing.same_results('base64 $input', '$the_executable $input')
}

fn test_expected() {
	mut f := os.open_file('textfile', 'w') or { panic(err) }
	f.write_string('Hello World!\nHow are you?') or {}
	f.close()

	mut g := os.open_file('base64file', 'w') or { panic(err) }
	g.write_string('ViBjb3JldXRpbHMgaXMgYXdlc29tZSEK') or {}
	g.close()

	expected_result('textfile', 'SGVsbG8gV29ybGQhCkhvdyBhcmUgeW91Pw==\n')
	expected_result('-w 0 textfile', 'SGVsbG8gV29ybGQhCkhvdyBhcmUgeW91Pw==')
	expected_result('-w 1 textfile', 'S\nG\nV\ns\nb\nG\n8\ng\nV\n2\n9\ny\nb\nG\nQ\nh\nC\nk\nh\nv\nd\ny\nB\nh\nc\nm\nU\ng\ne\nW\n9\n1\nP\nw\n=\n=\n')
	expected_result('-d base64file', 'V coreutils is awesome!\n')

	os.rm('textfile') or { panic(err) }
	os.rm('base64file') or { panic(err) }
}
