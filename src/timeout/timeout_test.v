import common.testing
import os

const rig = testing.prepare_rig(util: 'timeout')
const executable_under_test = rig.executable_under_test

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_timeout_basic() {
	// Timeout occurs
	res := os.execute('${executable_under_test} 1 sleep 2')
	assert res.exit_code == 124
}

fn test_timeout_normal_exit() {
	// Command exits before timeout
	res := os.execute('${executable_under_test} 2 sleep 1')
	assert res.exit_code == 0
}

fn test_timeout_preserve_status() {
	// preserve exit status
	res := os.execute('${executable_under_test} --preserve-status 1 sh -c "exit 42"')
	assert res.exit_code == 42
}

fn test_timeout_kill_after() {
	// Kill after
	res := os.execute('${executable_under_test} --kill-after=1 0.5 sleep 10')
	assert res.exit_code == 124
}

fn test_timeout_command_not_found() {
	// Command not found
	res := os.execute('${executable_under_test} 1 nonexistentcommand')
	assert res.exit_code == 127
}

fn test_timeout_invalid_signal() {
	// Invalid signal
	res := os.execute('${executable_under_test} --signal=INVALID 1 sleep 1')
	assert res.exit_code == 125
}

fn test_timeout_foreground() {
	// Foreground (should work same as default on most systems)
	res := os.execute('${executable_under_test} --foreground 1 sleep 2')
	assert res.exit_code == 124
}

fn test_timeout_infinite() {
	// Infinite duration should not timeout
	res := os.execute('${executable_under_test} infinity sleep 1')
	assert res.exit_code == 0
}

fn test_timeout_zero() {
	// Zero duration should not timeout
	res := os.execute('${executable_under_test} 0 sleep 1')
	assert res.exit_code == 0
}

fn test_timeout_permission_denied() {
	// Create a non-executable file
	os.write_file('nonexec', '#!/bin/bash\necho test') or {}
	os.chmod('nonexec', 0o644) or {}
	defer { os.rm('nonexec') or {} }
	res := os.execute('${executable_under_test} 1 ./nonexec')
	assert res.exit_code == 126
}

fn test_timeout_invalid_signal_range() {
	// Invalid signal number out of range
	res := os.execute('${executable_under_test} --signal=999 1 sleep 1')
	assert res.exit_code == 125
}

fn test_timeout_negative_duration() {
	// Negative duration should error
	res := os.execute('${executable_under_test} -1 sleep 1')
	// Should fail parsing, hopefully ?
	assert res.exit_code != 0
}
