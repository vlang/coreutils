import common.realpath as realpathmod
import common.testing
import os

const rig = testing.prepare_rig(util: 'realpath')

const repo = os.join_path(os.getwd(), '..', '..')

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
	p.wait()
	r := Run{
		code:   p.code
		stdout: p.stdout_slurp()
		stderr: p.stderr_slurp()
	}
	p.close()
	return r
}

fn run_uu(args []string) Run {
	mut p := os.new_process(rig.platform_util_path)
	mut full_args := ['realpath']
	full_args << args
	p.set_args(full_args)
	p.set_redirect_stdio()
	p.wait()
	r := Run{
		code:   p.code
		stdout: p.stdout_slurp()
		stderr: p.stderr_slurp()
	}
	p.close()
	return r
}

fn assert_same(args []string) {
	tr := run_tr(args)
	uu := run_uu(args)
	assert tr.code == uu.code, 'exit code for [${args}]: tr=${tr.code} uu=${uu.code}'
	assert tr.stdout == uu.stdout, 'stdout for [${args}]: tr=${tr.stdout} uu=${uu.stdout}'
}

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_matches_reference_absolute_and_relative() {
	assert_same([repo])
	assert_same(['.'])
	assert_same([os.join_path(repo, '.')])
	assert_same([os.join_path(repo, '..', 'coreutils')])
}

fn test_matches_reference_missing_paths() {
	assert_same(['C:\\nope\\x'])
	assert_same(['-e', 'C:\\nope'])
	assert_same(['-m', 'C:\\nope\\x\\y'])
	assert_same(['-q', 'C:\\nope\\x'])
}

fn test_matches_reference_no_symlinks() {
	assert_same(['-s', os.join_path(repo, '..', 'coreutils')])
	assert_same(['--no-symlinks', repo])
}

fn test_matches_reference_relative_options() {
	assert_same(['--relative-to=C:\\Users\\MR\\Projects', repo])
	assert_same(['--relative-to', 'C:\\Users\\MR', repo])
	assert_same(['--relative-base=C:\\Users\\MR\\Projects', repo])
	assert_same(['--relative-base=C:\\Users', 'C:\\nope\\deep'])
}

fn test_matches_reference_multiple_operands() {
	assert_same([repo, os.join_path(repo, '..', 'coreutils')])
}

fn test_parse_args_flags() {
	set := realpathmod.parse_args(['-e', '-m', '-s', '-z', '-q', 'x'])
	assert set.must_exist
	assert set.allow_missing
	assert set.no_symlinks
	assert set.zero_terminated
	assert set.quiet
	assert set.operands == ['x']
}

fn test_parse_args_long_forms() {
	e := realpathmod.parse_args(['--canonicalize-existing', '--canonicalize-missing', '--no-symlinks',
		'--zero', '--quiet', 'a', 'b'])
	assert e.must_exist
	assert e.allow_missing
	assert e.no_symlinks
	assert e.zero_terminated
	assert e.quiet
	assert e.operands == ['a', 'b']
}

fn test_parse_args_separator() {
	set := realpathmod.parse_args(['--', '-e'])
	assert set.operands == ['-e']
	assert !set.must_exist
}

fn test_parse_args_relative_value_forms() {
	a := realpathmod.parse_args(['--relative-to=/usr', 'x'])
	assert a.relative_to == '/usr'

	b := realpathmod.parse_args(['--relative-to', '/usr', 'x'])
	assert b.relative_to == '/usr'

	c := realpathmod.parse_args(['--relative-base=/usr', 'x'])
	assert c.relative_base == '/usr'
}

fn test_relative_from_diverging_paths() {
	assert realpathmod.relative_from('/usr/local/bin', '/usr') == 'local/bin'
	assert realpathmod.relative_from('/etc/passwd', '/usr') == '../etc/passwd'
	assert realpathmod.relative_from('/usr', '/usr') == '.'
	assert realpathmod.relative_from('/a/b/c', '/a/b') == 'c'
}

fn test_under_requires_a_separator_boundary() {
	// A base that is a strict string prefix is not an ancestor, so the
	// absolute path must be printed instead of a bogus relative one.
	assert realpathmod.under('/usr/local', '/usr/local')
	assert realpathmod.under('/usr/local/bin', '/usr')
	assert realpathmod.under('C:/Users/MR/x', 'C:/Users/MR')
	assert !realpathmod.under('/usr/local/bin', '/usr/loc')
	assert !realpathmod.under('/usr/local/bin', '/usr/local/bin/deeper')
	assert !realpathmod.under('/etc/passwd', '/usr')
	assert !realpathmod.under('/usrx', '/usr')
	assert !realpathmod.under('/usr/local/bin', '')
}
