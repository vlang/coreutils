import common.testing
import os

const rig = testing.prepare_rig(util: 'mv')

const src_path = 'mv_src.txt'
const dst_path = 'mv_dst.txt'
const dir_src = 'mv_src_dir'
const dir_dst = 'mv_dst_dir'

fn testsuite_begin() {
	os.write_file(src_path, 'the quick brown fox\n')!
	os.mkdir(dir_src)!
	os.write_file(os.join_path(dir_src, 'a.txt'), 'aaa\n')!
	os.write_file(os.join_path(dir_src, 'b.txt'), 'bbbb\n')!
	os.mkdir(os.join_path(dir_src, 'sub'))!
	os.write_file(os.join_path(dir_src, 'sub', 'c.txt'), 'cc\n')!
}

fn testsuite_end() {
	os.rm(src_path) or {}
	os.rm(dst_path) or {}
	for root in [dir_src, dir_dst] {
		os.rm(os.join_path(root, 'sub', 'c.txt')) or {}
		os.rm(os.join_path(root, 'a.txt')) or {}
		os.rm(os.join_path(root, 'b.txt')) or {}
		os.rmdir(os.join_path(root, 'sub')) or {}
		os.rmdir(root) or {}
	}
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_progress_is_listed_in_help() {
	res := os.execute('${rig.executable_under_test} --help')
	assert res.exit_code == 0
	assert res.output.contains('--progress')
}

fn test_progress_moves_a_file() {
	res := os.execute('${rig.executable_under_test} --progress ${src_path} ${dst_path}')
	assert res.exit_code == 0
	assert !os.exists(src_path)
	assert os.read_bytes(dst_path)! == 'the quick brown fox\n'.bytes()
}

fn test_progress_moves_a_directory() {
	res := os.execute('${rig.executable_under_test} --progress ${dir_src} ${dir_dst}')
	assert res.exit_code == 0
	assert !os.exists(dir_src)
	assert os.read_bytes(os.join_path(dir_dst, 'a.txt'))! == 'aaa\n'.bytes()
	assert os.read_bytes(os.join_path(dir_dst, 'b.txt'))! == 'bbbb\n'.bytes()
	assert os.read_bytes(os.join_path(dir_dst, 'sub', 'c.txt'))! == 'cc\n'.bytes()
}

// The directory tests above consume dir_src, so this one uses a source of its
// own rather than depending on the order the tests run in.
fn test_progress_draws_a_bar() {
	bar_src := 'mv_bar_src'
	bar_dst := 'mv_bar_dst'
	os.mkdir(bar_src)!
	os.write_file(os.join_path(bar_src, 'x.txt'), 'xxxx\n')!
	res := os.execute('${rig.executable_under_test} --progress ${bar_src} ${bar_dst}')
	assert res.exit_code == 0
	assert res.output.contains('100%')
	assert res.output.contains('[')
	os.rm(os.join_path(bar_dst, 'x.txt')) or {}
	os.rmdir(bar_dst) or {}
	os.rmdir(bar_src) or {}
}
