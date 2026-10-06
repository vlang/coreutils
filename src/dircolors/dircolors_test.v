import common.testing
import os

const rig = testing.prepare_rig(util: 'dircolors')

fn testsuite_begin() {
	// The database is only output when the terminal can show colours, and the
	// Windows build does not always see TERM as it is set elsewhere, so it is set
	// here rather than assumed.
	os.setenv('TERM', 'xterm', true)
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_bourne_shell_output() {
	res := os.execute('${rig.executable_under_test} -b')
	assert res.exit_code == 0
	assert res.output.starts_with("LS_COLORS='rs=0:")
	assert res.output.contains('export LS_COLORS')
}

fn test_c_shell_output() {
	res := os.execute('${rig.executable_under_test} -c')
	assert res.exit_code == 0
	assert res.output.starts_with("setenv LS_COLORS 'rs=0:")
}

fn test_no_term_outputs_empty() {
	os.setenv('TERM', 'dumb', true)
	res := os.execute('${rig.executable_under_test} -b')
	assert res.exit_code == 0
	assert res.output == "LS_COLORS='';\nexport LS_COLORS\n"
	os.setenv('TERM', 'xterm', true)
}

fn test_missing_database_file() {
	res := os.execute('${rig.executable_under_test} nosuchdb')
	assert res.exit_code == 1
	assert res.output.contains('No such file or directory')
}
