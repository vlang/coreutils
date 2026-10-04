import common.testing
import os

const rig = testing.prepare_rig(util: 'timeout')
const executable_under_test = rig.executable_under_test

// GNU has no timeout on native Windows at all, and neither does the reference this
// repository tests against on Windows:
//
//	coreutils timeout --version    timeout: function/utility not found
//
// build.vsh lists timeout among the utilities left out of the Windows build for the
// same reason. This port's timeout does compile and run there now, but there is
// nothing to compare it against and nothing to assert, so every test below returns
// early on Windows and says so once rather than failing in assert_platform_util.
fn no_reference_to_compare_with() bool {
	$if windows {
		println('no GNU timeout on Windows to compare with, skipping')
		return true
	}
	return false
}

fn testsuite_begin() {
	if no_reference_to_compare_with() {
		return
	}
	rig.assert_platform_util()
}

fn test_help_and_version() {
	if no_reference_to_compare_with() {
		return
	}
	rig.assert_help_and_version_options_work()
}

fn test_timeout_basic() {
	if no_reference_to_compare_with() {
		return
	}
	// Timeout occurs
	res := os.execute('${executable_under_test} 1 sleep 2')
	assert res.exit_code == 124
}

fn test_timeout_normal_exit() {
	if no_reference_to_compare_with() {
		return
	}
	// Command exits before timeout
	res := os.execute('${executable_under_test} 2 sleep 1')
	assert res.exit_code == 0
}

fn test_timeout_preserve_status() {
	if no_reference_to_compare_with() {
		return
	}
	// preserve exit status
	res := os.execute('${executable_under_test} --preserve-status 1 sh -c "exit 42"')
	assert res.exit_code == 42
}

fn test_timeout_kill_after() {
	if no_reference_to_compare_with() {
		return
	}
	// Kill after
	res := os.execute('${executable_under_test} --kill-after=1 0.5 sleep 10')
	assert res.exit_code == 124
}

fn test_timeout_command_not_found() {
	if no_reference_to_compare_with() {
		return
	}
	// Command not found
	res := os.execute('${executable_under_test} 1 nonexistentcommand')
	assert res.exit_code == 127
}

fn test_timeout_invalid_signal() {
	if no_reference_to_compare_with() {
		return
	}
	// Invalid signal
	res := os.execute('${executable_under_test} --signal=INVALID 1 sleep 1')
	assert res.exit_code == 125
}

fn test_timeout_foreground() {
	if no_reference_to_compare_with() {
		return
	}
	// Foreground (should work same as default on most systems)
	res := os.execute('${executable_under_test} --foreground 1 sleep 2')
	assert res.exit_code == 124
}

fn test_timeout_infinite() {
	if no_reference_to_compare_with() {
		return
	}
	// Infinite duration should not timeout
	res := os.execute('${executable_under_test} infinity sleep 1')
	assert res.exit_code == 0
}

fn test_timeout_zero() {
	if no_reference_to_compare_with() {
		return
	}
	// Zero duration should not timeout
	res := os.execute('${executable_under_test} 0 sleep 1')
	assert res.exit_code == 0
}

fn test_timeout_permission_denied() {
	if no_reference_to_compare_with() {
		return
	}
	// Create a non-executable file
	os.write_file('nonexec', '#!/bin/bash\necho test') or {}
	os.chmod('nonexec', 0o644) or {}
	defer { os.rm('nonexec') or {} }
	res := os.execute('${executable_under_test} 1 ./nonexec')
	assert res.exit_code == 126
}

fn test_timeout_invalid_signal_range() {
	if no_reference_to_compare_with() {
		return
	}
	// Invalid signal number out of range
	res := os.execute('${executable_under_test} --signal=999 1 sleep 1')
	assert res.exit_code == 125
}

fn test_timeout_negative_duration() {
	if no_reference_to_compare_with() {
		return
	}
	// Negative duration should error
	res := os.execute('${executable_under_test} -1 sleep 1')
	// Should fail parsing, hopefully ?
	assert res.exit_code != 0
}
