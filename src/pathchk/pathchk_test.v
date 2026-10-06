import common.testing
import os

const rig = testing.prepare_rig(util: 'pathchk')

// No assert_platform_util here: the reference uutils 0.0.17 has no pathchk, so
// `coreutils pathchk --version` exits 1 with "function/utility not found".
fn testsuite_begin() {
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

// os.exec with an argument array rather than os.execute with a string: a string
// goes through the shell on Windows, which splits a path containing a space and
// drops an empty argument, so neither the space case nor the empty case can be
// tested that way.
fn check(args []string) (int, string) {
	mut cmd := [rig.executable_under_test]
	cmd << args
	res := os.exec(cmd)
	return res.exit_code, res.output
}

fn test_valid_path() {
	code, out := check(['/tmp/foo'])
	assert code == 0
	assert out == ''
}

fn test_empty_path() {
	code, out := check([''])
	assert code == 1
	assert out.contains('No such file or directory')
}

fn test_portable_valid() {
	code, out := check(['-p', '/tmp/foo'])
	assert code == 0
	assert out == ''
}

fn test_portable_rejects_space() {
	code, out := check(['-p', '/tmp/foo bar'])
	assert code == 1
	assert out.contains('non-portable character')
}

fn test_strict_valid() {
	code, out := check(['-P', '/tmp/foo'])
	assert code == 0
	assert out == ''
}

fn test_strict_rejects_empty() {
	code, out := check(['-P', ''])
	assert code == 1
	assert out.contains('empty file name')
}

fn test_strict_rejects_leading_dash() {
	code, out := check(['-P', '--', '-foo'])
	assert code == 1
	assert out.contains("leading '-'")
}

fn test_nonexistent_is_not_an_error() {
	// pathchk checks the name, not whether the file is there, so a name that is
	// well formed passes whether or not it exists.
	code, _ := check(['-p', '/tmp/definitely_nonexistent_xyz'])
	assert code == 0
}

fn test_several_paths() {
	code, out := check(['/tmp/foo', '/tmp/bar'])
	assert code == 0
	assert out == ''
}

fn test_several_paths_one_bad() {
	code, out := check(['-p', '/tmp/foo', '/tmp/ba r'])
	assert code == 1
	assert out.contains('non-portable character')
}
