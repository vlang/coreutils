import common.testing
import os

const rig = testing.prepare_rig(util: 'cp')

const src_path = 'cp_src.txt'
const dst_path = 'cp_dst.txt'
const dir_src = 'cp_src_dir'
const dir_dst = 'cp_dst_dir'

fn testsuite_begin() {
	os.write_file(src_path, 'the quick brown fox\n')!
	os.mkdir(dir_src)!
	os.write_file(os.join_path(dir_src, 'a.txt'), 'aaa\n')!
	os.write_file(os.join_path(dir_src, 'b.txt'), 'bbbb\n')!
	os.mkdir(os.join_path(dir_src, 'sub'))!
	os.write_file(os.join_path(dir_src, 'sub', 'c.txt'), 'cc\n')!
}

fn testsuite_end() {
	// The two directory tests both write into dir_dst, so the tree is taken down
	// file by file. os.rmdir panics rather than reporting a non-empty directory, so
	// each step ignores its own failure.
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

// --progress is a long option with no short form, so it is spelled with two
// dashes. A single dash leaves it as a free argument and the copy fails.
fn test_progress_is_listed_in_help() {
	res := os.execute('${rig.executable_under_test} --help')
	assert res.exit_code == 0
	assert res.output.contains('--progress')
}

fn test_progress_copies_a_file() {
	res := os.execute('${rig.executable_under_test} --progress ${src_path} ${dst_path}')
	assert res.exit_code == 0
	assert os.read_bytes(dst_path)! == os.read_bytes(src_path)!
}

fn test_progress_copies_a_directory() {
	res := os.execute('${rig.executable_under_test} --progress -r ${dir_src} ${dir_dst}')
	assert res.exit_code == 0
	assert os.read_bytes(os.join_path(dir_dst, 'a.txt'))! == 'aaa\n'.bytes()
	assert os.read_bytes(os.join_path(dir_dst, 'b.txt'))! == 'bbbb\n'.bytes()
	assert os.read_bytes(os.join_path(dir_dst, 'sub', 'c.txt'))! == 'cc\n'.bytes()
}

// The bar is drawn on standard error, which os.execute captures along with
// standard output. It is a sequence of carriage-terminated updates ending at
// 100%, so the last one is the one to look for.
fn test_progress_draws_a_bar() {
	res := os.execute('${rig.executable_under_test} --progress -r ${dir_src} ${dir_dst}')
	assert res.exit_code == 0
	assert res.output.contains('100%')
	assert res.output.contains('[')
}
