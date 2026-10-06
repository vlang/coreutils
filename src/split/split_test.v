import common.testing
import os

const rig = testing.prepare_rig(util: 'split')

const input_path = 'split_input.txt'

fn testsuite_begin() {
	os.write_file(input_path, 'a\nb\nc\nd\ne\nf\ng\nh\n')!
}

fn testsuite_end() {
	os.rm(input_path) or {}
	// The output files are named by the prefix and suffix, so they are taken down
	// by pattern rather than by a list that has to be kept in step with the tests.
	for f in os.ls('.') or { [] } {
		if f.starts_with('x') && f.len == 3 {
			os.rm(f) or {}
		}
	}
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_lines() {
	res := os.execute('${rig.executable_under_test} -l 3 ${input_path}')
	assert res.exit_code == 0
	assert os.read_file('xaa')! == 'a\nb\nc\n'
	assert os.read_file('xab')! == 'd\ne\nf\n'
	assert os.read_file('xac')! == 'g\nh\n'
}

fn test_bytes() {
	// -b 3 cuts on the byte count, which lands inside a line: the pieces are
	// a\nb, \nc\n, d\ne and so on, and the last holds whatever is left.
	res := os.execute('${rig.executable_under_test} -b 3 ${input_path}')
	assert res.exit_code == 0
	assert os.read_file('xaa')! == 'a\nb'
	assert os.read_file('xab')! == '\nc\n'
	assert os.read_file('xac')! == 'd\ne'
	assert os.read_file('xad')! == '\nf\n'
	assert os.read_file('xae')! == 'g\nh'
	assert os.read_file('xaf')! == '\n'
}

fn test_line_bytes_never_breaks_a_line() {
	// -C 4 over eight one byte lines: two lines fit in four bytes, so the cut lands
	// on a line boundary even though a third line would only take two more.
	res := os.execute('${rig.executable_under_test} -C 4 ${input_path}')
	assert res.exit_code == 0
	assert os.read_file('xaa')! == 'a\nb\n'
	assert os.read_file('xab')! == 'c\nd\n'
	assert os.read_file('xac')! == 'e\nf\n'
	assert os.read_file('xad')! == 'g\nh\n'
}

fn test_suffix_length() {
	res := os.execute('${rig.executable_under_test} -l 4 -a 1 ${input_path}')
	assert res.exit_code == 0
	assert os.read_file('xa')! == 'a\nb\nc\nd\n'
	assert os.read_file('xb')! == 'e\nf\ng\nh\n'
}

fn test_numeric_suffixes() {
	res := os.execute('${rig.executable_under_test} -l 4 -d ${input_path}')
	assert res.exit_code == 0
	assert os.read_file('x00')! == 'a\nb\nc\nd\n'
	assert os.read_file('x01')! == 'e\nf\ng\nh\n'
}

fn test_custom_prefix() {
	res := os.execute('${rig.executable_under_test} -l 4 ${input_path} out')
	assert res.exit_code == 0
	assert os.read_file('outaa')! == 'a\nb\nc\nd\n'
	assert os.read_file('outab')! == 'e\nf\ng\nh\n'
}

fn test_missing_file() {
	res := os.execute('${rig.executable_under_test} -l 4 nosuchfile')
	assert res.exit_code == 1
	assert res.output.contains('No such file or directory')
}

fn test_two_ways_to_cut_is_refused() {
	res := os.execute('${rig.executable_under_test} -l 4 -b 2 ${input_path}')
	assert res.exit_code == 1
	assert res.output.contains('cannot split in more than one way')
}
