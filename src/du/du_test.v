// Compiled on its own by `v test src/du/`, so the logic under test is
// imported from common/du rather than defined here.
import common.du as dumod
import common.testing
import os

const rig = testing.prepare_rig(util: 'du')

const tree_base = os.join_path(os.temp_dir(), 'du_test_tree')

fn make_tree() {
	base := tree_base
	os.rmdir_all(base) or {}
	os.mkdir_all(os.join_path(base, 'a', 'b')) or { panic('mkdir a/b: ${err}') }
	os.mkdir_all(os.join_path(base, 'c')) or { panic('mkdir c: ${err}') }
	os.write_file(os.join_path(base, 'big.dat'), '0123456789') or { panic('write: ${err}') }
	os.write_file(os.join_path(base, 'a', 'one.txt'), 'hi') or { panic('write: ${err}') }
	os.write_file(os.join_path(base, 'a', 'b', 'two.txt'), 'hey') or { panic('write: ${err}') }
	os.write_file(os.join_path(base, 'c', 't.txt'), 'x') or { panic('write: ${err}') }
}

fn path(parts ...string) string {
	return parts.join(os.path_separator)
}

fn line(size string, parts ...string) string {
	return size + '\t' + parts.join(os.path_separator)
}

fn testsuite_begin() {
	rig.assert_platform_util()
	make_tree()
}

fn testsuite_end() {
	os.rmdir_all(tree_base) or {}
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_bytes_recursive() {
	set := dumod.parse_args(['-b', tree_base])
	out, failed := dumod.report(set)
	assert !failed
	expected := line('3', tree_base, 'a', 'b') + '\n' + line('5', tree_base, 'a') + '\n' +
		line('1', tree_base, 'c') + '\n' + line('16', tree_base)
	assert out == expected
}

fn test_bytes_all_files() {
	set := dumod.parse_args(['-b', '-a', tree_base])
	out, failed := dumod.report(set)
	assert !failed
	// Entries are visited alphabetically, parents after their children.
	expected := line('3', tree_base, 'a', 'b', 'two.txt') + '\n' + line('3', tree_base, 'a', 'b') +
		'\n' + line('2', tree_base, 'a', 'one.txt') + '\n' + line('5', tree_base, 'a') + '\n' +
		line('10', tree_base, 'big.dat') + '\n' + line('1', tree_base, 'c', 't.txt') + '\n' +
		line('1', tree_base, 'c') + '\n' + line('16', tree_base)
	assert out == expected
}

fn test_summarize() {
	set := dumod.parse_args(['-b', '-s', tree_base])
	out, failed := dumod.report(set)
	assert !failed
	assert out == line('16', tree_base)
}

fn test_total() {
	set := dumod.parse_args(['-b', '-c', tree_base])
	out, failed := dumod.report(set)
	assert !failed
	assert out.ends_with(line('16', 'total'))
	// -c keeps the per-directory lines as well as the grand total.
	assert out.contains(line('5', tree_base, 'a'))
}

fn test_max_depth() {
	set := dumod.parse_args(['-b', '-d', '1', tree_base])
	out, failed := dumod.report(set)
	assert !failed
	assert out == line('5', tree_base, 'a') + '\n' + line('1', tree_base, 'c') + '\n' +
		line('16', tree_base)

	deep := dumod.parse_args(['-b', '-d', '0', tree_base])
	out2, _ := dumod.report(deep)
	assert out2 == line('16', tree_base)
}

fn test_file_operand() {
	target := path(tree_base, 'big.dat')
	set := dumod.parse_args(['-b', target])
	out, failed := dumod.report(set)
	assert !failed
	// A file named on the command line is shown without -a.
	assert out == line('10', target)
}

fn test_missing_path_reports_and_fails() {
	missing := path(tree_base, 'missing')
	good := path(tree_base, 'a')
	set := dumod.parse_args(['-b', missing, good])
	out, failed := dumod.report(set)
	assert failed
	assert out.starts_with('du: cannot access ${missing}: No such file or directory\n')
	assert out.ends_with(line('5', good))
}

fn test_format_size_rounds_up() {
	base := dumod.parse_args([])
	assert dumod.format_size(0, base) == '0'
	// A single byte still occupies a whole block, so it is one, not zero.
	assert dumod.format_size(1, base) == '1'
	assert dumod.format_size(1024, base) == '1'
	assert dumod.format_size(1025, base) == '2'
	assert dumod.format_size(16, base) == '1'

	bytes := dumod.parse_args(['-b'])
	assert dumod.format_size(16, bytes) == '16'
	assert dumod.format_size(1, bytes) == '1'
}

fn test_format_size_other_units() {
	k := dumod.parse_args(['-k'])
	// One MiB is 1024 one-KiB blocks.
	assert dumod.format_size(1024 * 1024, k) == '1024'
	assert dumod.format_size(1025, k) == '2'

	m := dumod.parse_args(['-m'])
	assert dumod.format_size(1024 * 1024, m) == '1'
	assert dumod.format_size(1024 * 1024 - 1, m) == '1'

	b := dumod.parse_args(['-B', '512'])
	assert dumod.format_size(1024, b) == '2'

	h := dumod.parse_args(['-h'])
	assert dumod.format_size(0, h) == '0'
	assert dumod.format_size(1024, h) == '1.0K'
	assert dumod.format_size(6450, h) == '6.3K'
	assert dumod.format_size(16 * 1024 * 1024, h) == '16M'

	si := dumod.parse_args(['--si'])
	assert dumod.format_size(1000, si) == '1.0k'
	assert dumod.format_size(6450, si) == '6.5k'
}

fn test_parse_args_modes() {
	assert dumod.parse_args(['-b']).mode == .bytes
	assert dumod.parse_args(['--bytes']).mode == .bytes
	// --apparent-size is -b's long spelling and means the same thing here.
	assert dumod.parse_args(['--apparent-size']).mode == .bytes
	assert dumod.parse_args(['-h']).mode == .human
	assert dumod.parse_args(['-H']).mode == .si_human
	assert dumod.parse_args(['-k']).mode == .kibibytes
	assert dumod.parse_args(['-m']).mode == .mebibytes
	assert dumod.parse_args(['-g']).mode == .gibibytes
}

fn test_parse_args_flags() {
	assert dumod.parse_args(['-a']).all
	assert dumod.parse_args(['--all']).all
	assert dumod.parse_args(['-s']).summary
	assert dumod.parse_args(['-c']).total
	assert dumod.parse_args(['--total']).total
	assert dumod.parse_args(['-d', '3']).max_depth == 3
	assert dumod.parse_args(['-d3']).max_depth == 3
	assert dumod.parse_args(['--max-depth=3']).max_depth == 3
	assert dumod.parse_args(['-B', '512']).block_size == 512
	assert dumod.parse_args(['-B512']).block_size == 512
}

fn test_parse_args_clusters() {
	set := dumod.parse_args(['-sh'])
	assert set.summary
	assert set.mode == .human

	set2 := dumod.parse_args(['-ab'])
	assert set2.all
	assert set2.mode == .bytes

	set3 := dumod.parse_args(['-sb', 'x'])
	assert set3.summary
	assert set3.mode == .bytes
	assert set3.operands == ['x']
}

fn test_parse_args_separator_and_dash() {
	set := dumod.parse_args(['--', '-b'])
	assert set.operands == ['-b']
	assert set.mode == .kibibytes

	// A lone '-' means standard input, and du has no stdin mode here, so it
	// is simply passed through as a path.
	set2 := dumod.parse_args(['-'])
	assert set2.operands == ['-']
}

fn test_no_operands_uses_dot() {
	set := dumod.parse_args([])
	assert set.operands.len == 0
}
