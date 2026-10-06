import common.testing
import os

const rig = testing.prepare_rig(util: 'tr')

const input_path = 'tr_input.txt'
const input_content = 'hello world 123\n'

struct Run {
mut:
	code   int
	stdout string
	stderr string
}

fn run_tr(args []string) Run {
	mut p := os.new_process(rig.executable_under_test)
	p.set_args(args)
	p.set_redirect_stdio()
	p.set_stdin_path(input_path)
	p.wait()
	mut r := Run{
		code:   p.code
		stdout: p.stdout_slurp()
		stderr: p.stderr_slurp()
	}
	p.close()
	return r
}

fn run_gnu(args []string) Run {
	mut p := os.new_process(rig.platform_util_call)
	p.set_args(args)
	p.set_redirect_stdio()
	p.set_stdin_path(input_path)
	p.wait()
	mut r := Run{
		code:   p.code
		stdout: p.stdout_slurp()
		stderr: p.stderr_slurp()
	}
	p.close()
	return r
}

fn assert_tr_matches_gnu(args []string) {
	gnu := run_gnu(args)
	tr := run_tr(args)
	assert tr.code == gnu.code, 'exit code: tr=${tr.code} gnu=${gnu.code}'
	assert tr.stdout == gnu.stdout, 'stdout: tr=${tr.stdout} gnu=${gnu.stdout}'
	assert tr.stderr == gnu.stderr, 'stderr: tr=${tr.stderr} gnu=${gnu.stderr}'
}

fn testsuite_begin() {
	rig.assert_platform_util()
	os.write_file(input_path, input_content)!
}

fn testsuite_end() {
	os.rm(input_path) or {}
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_basic_translation() {
	assert_tr_matches_gnu(['a-z', 'A-Z'])
	assert_tr_matches_gnu(['A-Z', 'a-z'])
	assert_tr_matches_gnu(['0-9', 'a-z'])
}

fn test_delete() {
	assert_tr_matches_gnu(['-d', 'a-z'])
	assert_tr_matches_gnu(['-d', 'A-Z'])
	assert_tr_matches_gnu(['-d', '0-9'])
}

fn test_squeeze() {
	assert_tr_matches_gnu(['-s', ' '])
	assert_tr_matches_gnu(['-s', 'a-z'])
}

fn test_complement() {
	assert_tr_matches_gnu(['-c', 'a-z', 'A-Z'])
}

fn test_delete_and_squeeze() {
	assert_tr_matches_gnu(['-ds', 'a-z', 'A-Z'])
}

fn test_character_classes() {
	assert_tr_matches_gnu(['[:lower:]', '[:upper:]'])
	assert_tr_matches_gnu(['[:upper:]', '[:lower:]'])
	assert_tr_matches_gnu(['[:digit:]', 'X'])
}

fn test_backslash_escapes() {
	assert_tr_matches_gnu(['\\n', 'X'])
}
