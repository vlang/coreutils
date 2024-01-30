import common.testing
import os
import time

const rig = testing.prepare_rig(util: 'uname')
const cmd = rig.cmd
const executable_under_test = rig.executable_under_test

fn test_help_and_version() {
	cmd.ensure_help_and_version_options_work()!
}

fn test_unknown_option() {
	testing.command_fails('${executable_under_test} -x')!
	testing.command_fails('${executable_under_test} -sm -vx')!
	testing.command_fails('${executable_under_test} -sm a')!
}

fn test_print_system_info() {
	assert cmd.same_results('')
	// assert cmd.same_results('--all')
	assert cmd.same_results('--kernel-name')
	assert cmd.same_results('--nodename')
	assert cmd.same_results('--kernel-release')
	assert cmd.same_results('--kernel-version')
	assert cmd.same_results('--machine')
	/*
	assert cmd.same_results('--processor')
	assert cmd.same_results('--hardware-platform')
	assert cmd.same_results('--operating-system')*/

	// assert cmd.same_results('-a')
	// assert cmd.same_results('-ma')
	assert cmd.same_results('-vm -srn')
}
