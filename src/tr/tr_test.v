import common.testing
import os

const rig = testing.prepare_rig(util: 'tr')

const input_path = 'tr_input.txt'
const input_content = 'hello world 123\n'
const case_input_path = 'tr_case_input.txt'

struct Run {
mut:
	code   int
	stdout string
	stderr string
}

fn run_tr_on(args []string, stdin_path string) Run {
	mut p := os.new_process(rig.executable_under_test)
	p.set_args(args)
	p.set_redirect_stdio()
	p.set_stdin_path(stdin_path)
	p.wait()
	mut r := Run{
		code:   p.code
		stdout: p.stdout_slurp()
		stderr: p.stderr_slurp()
	}
	p.close()
	return r
}

fn run_gnu_on(args []string, stdin_path string) Run {
	mut full_args := ['tr']
	full_args << args
	mut p := os.new_process(rig.platform_util_path)
	p.set_args(full_args)
	p.set_redirect_stdio()
	p.set_stdin_path(stdin_path)
	p.wait()
	mut r := Run{
		code:   p.code
		stdout: p.stdout_slurp()
		stderr: p.stderr_slurp()
	}
	p.close()
	return r
}

fn run_tr(args []string) Run {
	return run_tr_on(args, input_path)
}

fn run_gnu(args []string) Run {
	return run_gnu_on(args, input_path)
}

fn assert_tr_matches_gnu(args []string) {
	gnu := run_gnu(args)
	tr := run_tr(args)
	assert tr.code == gnu.code, 'exit code: tr=${tr.code} gnu=${gnu.code}'
	assert tr.stdout == gnu.stdout, 'stdout: tr=${tr.stdout} gnu=${gnu.stdout}'
	assert tr.stderr == gnu.stderr, 'stderr: tr=${tr.stderr} gnu=${gnu.stderr}'
}

fn assert_tr_matches_gnu_with_input(args []string, content string) {
	os.write_file(case_input_path, content) or { panic('cannot write case input: ${err.msg()}') }
	gnu := run_gnu_on(args, case_input_path)
	tr := run_tr_on(args, case_input_path)
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
	os.rm(case_input_path) or {}
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
	assert_tr_matches_gnu(['[:alnum:]', 'X'])
	assert_tr_matches_gnu(['[:punct:]', 'X'])
	assert_tr_matches_gnu(['[:xdigit:]', 'X'])
	assert_tr_matches_gnu_with_input(['[:blank:]', 'X'], 'a\tb c\n')
	assert_tr_matches_gnu_with_input(['[:space:]', 'X'], 'a\tb\vc\fd e\n')
}

fn test_backslash_escapes() {
	assert_tr_matches_gnu(['\\n', 'X'])
	assert_tr_matches_gnu_with_input(['\\101', 'X'], 'ABCD\n')
	assert_tr_matches_gnu_with_input(['\\0', 'X'], 'a' + u8(0).ascii_str() + 'b\n')
	assert_tr_matches_gnu_with_input(['\\a\\b\\f\\v', 'WXYZ'], 'a' + u8(7).ascii_str() + u8(8).ascii_str() +
		u8(12).ascii_str() + u8(11).ascii_str() + 'b\n')
}

fn test_translate_and_squeeze() {
	assert_tr_matches_gnu(['-s', 'a-z', 'A-Z'])
	assert_tr_matches_gnu_with_input(['-s', 'a-z', 'A-Z'], 'aabb\n')
}

fn test_truncate() {
	assert_tr_matches_gnu_with_input(['-t', 'a-z', 'AB'], 'abacus\n')
	assert_tr_matches_gnu_with_input(['-t', 'a-z', ''], 'abacus\n')
}

fn test_complement_delete_and_squeeze() {
	assert_tr_matches_gnu(['-dc', 'a-z'])
	assert_tr_matches_gnu_with_input(['-sc', 'a-z'], 'aa  bb\n')
	assert_tr_matches_gnu_with_input(['-ds', 'a-z'], 'aa  bb\n')
}

fn test_repeat() {
	assert_tr_matches_gnu_with_input(['abcd', '[X*]'], 'abcd\n')
	assert_tr_matches_gnu_with_input(['abcdef', '[X*3]Y'], 'abcdef\n')
}

fn test_empty_set2() {
	// GNU 9.4 and uutils 0.0.17 agree on the exit code (1) and the empty
	// stdout here, but differ on stderr by one blank line:
	//	GNU:    'tr: when not truncating set1, string2 must be non-empty\n'
	//	uutils: 'tr: when not truncating set1, string2 must be non-empty\n\n'
	// This port matches GNU, so these cases pin the GNU bytes instead of
	// comparing stderr against the reference.
	assert_tr_error_matches_gnu(['a-z', ''], input_content, 'tr: when not truncating set1, string2 must be non-empty\n')
	assert_tr_error_matches_gnu(['-s', 'a-z', ''], 'aabb\n', 'tr: when not truncating set1, string2 must be non-empty\n')
}

fn test_bare_star_in_set1() {
	// Same stderr shape as above: GNU prints the message once, uutils
	// 0.0.17 appends a blank line. This port matches GNU.
	assert_tr_error_matches_gnu(['[a*]', 'X'], 'aaab\n', 'tr: the [c*] repeat construct may not appear in string1\n')
}

// assert_tr_error_matches_gnu checks an operand error end to end: both tools
// must fail with empty stdout, and this tool's stderr must equal the recorded
// GNU 9.4 bytes.
fn assert_tr_error_matches_gnu(args []string, content string, gnu_stderr string) {
	os.write_file(case_input_path, content) or { panic('cannot write case input: ${err.msg()}') }
	gnu := run_gnu_on(args, case_input_path)
	tr := run_tr_on(args, case_input_path)
	assert tr.code == 1, 'exit code: tr=${tr.code}'
	assert gnu.code == 1, 'reference exit code changed: gnu=${gnu.code}'
	assert tr.stdout == '', 'stdout should be empty: tr=${tr.stdout}'
	assert gnu.stdout == '', 'reference stdout changed: gnu=${gnu.stdout}'
	assert tr.stderr == gnu_stderr, 'stderr: tr=${tr.stderr} gnu=${gnu_stderr}'
}
