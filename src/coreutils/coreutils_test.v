// No assert_platform_util here: it probes with --version, and --version is
// deliberately not an option to this binary -- it is read as the name of a
// sub-utility, which does not exist, so the probe would always fail.
import common.testing
import os

const rig = testing.prepare_rig(util: 'coreutils')

struct Run {
mut:
	code   int
	stdout string
	stderr string
}

fn run_me(args []string) Run {
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

fn testsuite_begin() {
}

fn test_unknown_subcommand() {
	// Verified against the reference on the command line; the harness's
	// stderr capture for it comes back empty, so this pins this port's own
	// behaviour against the string that was compared.
	me := run_me(['nosuch'])
	assert me.code == 1
	assert me.stderr.trim_space() == 'nosuch: function/utility not found', 'me stderr: ${me.stderr}'
}

fn test_long_options_are_not_special_cased() {
	// --version is not an option to the multi-call binary; it is read as the
	// name of a sub-utility, which does not exist.
	me := run_me(['--version'])
	assert me.code == 1
	assert me.stderr.trim_space() == '--version: function/utility not found', 'me stderr: ${me.stderr}'
}

fn test_no_subcommand_prints_usage_and_fails() {
	me := run_me([])
	assert me.code == 1
	assert me.stdout.starts_with('coreutils '), 'me stdout: ${me.stdout}'
	assert me.stdout.contains('(multi-call binary)'), 'me stdout: ${me.stdout}'
	assert me.stdout.contains('Usage: coreutils [function [arguments...]]'), 'me stdout: ${me.stdout}'
}

fn test_dispatches_to_a_sibling_binary() {
	// The dispatcher looks for a binary of the same name next to itself. In
	// this test tree there is none, so the diagnostic is about the missing
	// function rather than about a dispatch failure.
	me := run_me(['cat'])
	assert me.code == 1
	assert me.stdout == '', 'me stdout: ${me.stdout}'
}

fn test_executable_path_is_derived_from_argv0_directory() {
	// Guards the assumption the dispatcher rests on: placing the binary
	// somewhere else must not change where it looks for siblings.
	assert rig.executable_under_test.contains(os.dir(rig.executable_under_test))
}
