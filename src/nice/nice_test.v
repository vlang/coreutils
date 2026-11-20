// No TestRig here: uutils 0.0.17 ships no nice for Windows, so GNU 9.4 through
// WSL is the reference, and the exit statuses were compared case by case there.
import common.nice as nicemod
import os

const work_dir = os.join_path(os.temp_dir(), 'nice_test_tree')

fn testsuite_begin() {
	os.rmdir_all(work_dir) or {}
	os.mkdir_all(work_dir) or { panic('mkdir: ${err}') }
}

fn testsuite_end() {
	os.rmdir_all(work_dir) or {}
}

fn test_parse_args_a_bare_number_is_the_command() {
	// "nice 5" must treat 5 as the command, not an adjustment, which is why
	// GNU reports "nice: ‘5’: No such file or directory" and exits 127.
	s := nicemod.parse_args(['5'])
	assert !s.adjustment_given
	assert s.command == ['5']
}

fn test_parse_args_adjustment_spellings() {
	// -n 5, -n5, --adjustment=5, --adjustment 5 and -5 all mean five. This
	// test is also the regression guard for an infinite loop: --adjustment=5
	// used to leave the argument index unmoved, so parsing it never returned.
	for spec in [['-n', '5'], ['-n5'], ['--adjustment=5'], ['--adjustment', '5'], ['-5']] {
		s := nicemod.parse_args(spec)
		assert s.adjustment == 5, 'spec ${spec} gave ${s.adjustment}'
		assert s.adjustment_given
	}
}

fn test_parse_args_negative_adjustment() {
	s := nicemod.parse_args(['-n', '-5'])
	assert s.adjustment == -5
	assert s.adjustment_given
}

fn test_parse_args_double_dash_forces_the_command() {
	// Everything after -- is the command even when it looks like an option.
	s := nicemod.parse_args(['-n', '5', '--', '-weird-cmd'])
	assert s.command == ['-weird-cmd']

	t := nicemod.parse_args(['--'])
	assert t.command.len == 0
}

fn test_parse_args_bare_invocation_has_no_command() {
	s := nicemod.parse_args([])
	assert s.command.len == 0
	assert !s.adjustment_given
}

fn test_parse_args_command_with_arguments() {
	// The command and everything after it are passed through untouched.
	s := nicemod.parse_args(['-n', '5', 'printf', '%s-%s', 'a', 'b'])
	assert s.adjustment == 5
	assert s.command == ['printf', '%s-%s', 'a', 'b']
}

fn test_parse_args_adjustment_then_command() {
	// The adjustment must be consumed before the command is read, so the
	// command does not swallow the value.
	s := nicemod.parse_args(['--adjustment', '7', 'cmd', 'arg'])
	assert s.adjustment == 7
	assert s.command == ['cmd', 'arg']
}
