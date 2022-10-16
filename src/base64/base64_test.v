import os
import common.testing

const the_executable = testing.prepare_executable('base64')

const cmd = testing.new_paired_command('base64', the_executable)

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn test_abcd() {
	res := os.execute('$the_executable abcd')
	assert res.exit_code == 1
	assert res.output.trim_space() == 'base64: abcd: No such file or directory'
}

fn expected_result(input string, output string) {
	c := '$the_executable $input'
	res := os.execute(c)
	eprintln('>>>> cmd: `$c`')
	if res.exit_code != 0 || res.output != output {
		eprintln('>>>> res.exit_code: $res.exit_code')
		eprintln('>>>> res.output   : `$res.output`')
		eprintln('>>>> expected     : `$output`')
	}
	assert res.exit_code == 0
	assert res.output == output
	testing.same_results('base64 $input', '$the_executable $input')
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
