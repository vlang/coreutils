import common.testing
import os

const rig = testing.prepare_rig(util: 'tsort')

const chain_path = 'tsort_chain.txt'
const cycle_path = 'tsort_cycle.txt'
const odd_path = 'tsort_odd.txt'
const empty_path = 'tsort_empty.txt'
const dup_path = 'tsort_dup.txt'
const self_path = 'tsort_self.txt'

fn testsuite_begin() {
	os.write_file(chain_path, 'a b\nb c\nc d\n')!
	os.write_file(cycle_path, 'a b\nb a\n')!
	os.write_file(odd_path, 'a\n')!
	os.write_file(empty_path, '')!
}

fn testsuite_end() {
	for f in [chain_path, cycle_path, odd_path, empty_path] {
		os.rm(f) or {}
	}
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_chain() {
	res := os.execute('${rig.executable_under_test} ${chain_path}')
	assert res.exit_code == 0
	assert res.output == 'a\nb\nc\nd\n'
}

fn test_cycle_reports_loop() {
	res := os.execute('${rig.executable_under_test} ${cycle_path}')
	assert res.exit_code == 1
	assert res.output.contains('input contains a loop')
}

fn test_odd_number_of_tokens() {
	res := os.execute('${rig.executable_under_test} ${odd_path}')
	assert res.exit_code == 1
	assert res.output.contains('odd number of tokens')
}

fn test_empty_input() {
	res := os.execute('${rig.executable_under_test} ${empty_path}')
	assert res.exit_code == 0
	assert res.output == ''
}

fn test_missing_file() {
	res := os.execute('${rig.executable_under_test} nosuchfile')
	assert res.exit_code == 1
	assert res.output.contains('No such file or directory')
}

fn test_reads_stdin_when_no_file() {
	res := os.execute('${rig.executable_under_test} < ${chain_path}')
	assert res.exit_code == 0
	assert res.output == 'a\nb\nc\nd\n'
}

fn test_duplicate_pairs_are_fine() {
	// The same pair twice is not an error: the edge is simply there once.
	os.write_file(dup_path, 'a b\na b\n')!
	res := os.execute('${rig.executable_under_test} ${dup_path}')
	assert res.exit_code == 0
	assert res.output == 'a\nb\n'
	os.rm(dup_path) or {}
}

fn test_self_loop_is_not_a_cycle() {
	// a a is a self loop, which GNU does not treat as a cycle: the node is printed
	// once and the exit code is 0.
	os.write_file(self_path, 'a a\n')!
	res := os.execute('${rig.executable_under_test} ${self_path}')
	assert res.exit_code == 0
	assert res.output == 'a\n'
	os.rm(self_path) or {}
}
