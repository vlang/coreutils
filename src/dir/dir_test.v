// No TestRig here: the reference is GNU 9.4 through WSL, because GNU's own
// -S ordering was measurable there and uutils on Windows disagrees with it by
// putting directories last instead of first. GNU is the authority, so the tests
// pin GNU's behaviour.
import common.dir as dirmod
import common.testing
import os

const rig = testing.prepare_rig(util: 'dir')

fn work_dir() string {
	return os.join_path(os.temp_dir(), 'dir_test_tree')
}

fn sub_dir() string {
	return os.join_path(work_dir(), 'sub')
}

fn make_tree() {
	os.rmdir_all(work_dir()) or {}
	os.mkdir_all(work_dir()) or { panic('mkdir: ${err}') }
	os.mkdir_all(sub_dir()) or { panic('mkdir sub: ${err}') }
	os.write_file(os.join_path(work_dir(), 'one.txt'), 'aa') or { panic('write: ${err}') }
	os.write_file(os.join_path(work_dir(), 'two.txt'), 'bb') or { panic('write: ${err}') }
	os.write_file(os.join_path(sub_dir(), 'nested.txt'), 'cc') or { panic('write: ${err}') }
}

fn testsuite_begin() {
	rig.assert_platform_util()
	make_tree()
}

fn testsuite_end() {
	os.rmdir_all(work_dir()) or {}
}

fn run_dir(args []string) (string, int) {
	return dirmod.run(dirmod.parse_args(args))
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_default_is_columns_not_one_per_line() {
	out, code := run_dir([work_dir()])
	assert code == 0
	assert out == 'one.txt  sub  two.txt'
}

fn test_one_per_line() {
	out, _ := run_dir(['-1', work_dir()])
	assert out == 'one.txt\nsub\ntwo.txt'
}

fn test_all_includes_dot_entries() {
	out, _ := run_dir(['-a', work_dir()])
	assert out == '.  ..  one.txt  sub  two.txt'
}

fn test_reverse() {
	out, _ := run_dir(['-r', work_dir()])
	assert out == 'two.txt  sub  one.txt'
}

fn test_no_line_ends_in_trailing_spaces() {
	// Padding is per column and the last column carries none.
	out, _ := run_dir([work_dir()])
	for line in out.split('\n') {
		has_trailing := line.len > 0 && line[line.len - 1] == ` `
		assert !has_trailing, 'trailing space in: ${line}'
	}
}

fn test_size_sort_puts_directories_first() {
	// GNU orders -S with the largest first, and a directory reports a larger
	// size than these two 2-byte files. uutils on Windows puts directories
	// last, which is the one case this port deliberately does not match.
	out, _ := run_dir(['-S', work_dir()])
	assert out.starts_with('sub')
}

fn test_recursion_lists_subdirectories_with_headers() {
	out, _ := run_dir(['-R', work_dir()])
	assert out.contains('${work_dir()}:')
	assert out.contains('${sub_dir()}:')
	assert out.contains('nested.txt')
}

fn test_missing_path_exits_two() {
	// GNU exits 2 for a path it cannot access, not 1.
	out_name := os.join_path(work_dir(), 'does-not-exist')
	_, code := run_dir([out_name])
	assert code == 2
}

fn test_parse_args_defaults() {
	s := dirmod.parse_args([])
	assert !s.all
	assert !s.recursive
	assert !s.one_per_line
	assert !s.by_time
	assert !s.by_size
	assert s.width == 80
}

fn test_parse_args_clusters() {
	s := dirmod.parse_args(['-aR'])
	assert s.all
	assert s.recursive

	t := dirmod.parse_args(['-1', '-r', '-S'])
	assert t.one_per_line
	assert t.reverse
	assert t.by_size
}

fn test_parse_args_width_forms() {
	for spec in [['-w', '40'], ['-w40'], ['--width=40'], ['--width', '40']] {
		s := dirmod.parse_args(spec)
		assert s.width == 40, 'spec ${spec} gave ${s.width}'
	}
}

fn test_no_operand_means_current_directory() {
	s := dirmod.parse_args([])
	assert s.operands.len == 0
}
