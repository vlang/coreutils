module main

import common.testing
import os

const rig = testing.prepare_rig(util: 'truncate')

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn testsuite_end() {
	rig.clean_up()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_size_parser() {
	mut s := parse_size_opt('0')
	assert s.mode == .absolute
	assert s.size == 0

	s = parse_size_opt('+256MiB')
	assert s.mode == .add
	assert s.size == 256 * 1024 * 1024

	s = parse_size_opt('-24GB')
	assert s.mode == .subtract
	assert s.size == 24 * 1000 * 1000 * 1000

	s = parse_size_opt('<13kB')
	assert s.mode == .at_most
	assert s.size == 13 * 1000

	s = parse_size_opt('>29KiB')
	assert s.mode == .at_least
	assert s.size == 29 * 1024

	mut t := parse_size_opt('>29k')
	assert s == t
	t = parse_size_opt('<29k')
	assert s.mode != t.mode
	assert s.size == t.size

	s = parse_size_opt('/14PB')
	assert s.mode == .round_down
	assert s.size == 14 * 1000 * 1000 * 1000 * 1000 * 1000
	assert s != t

	s = parse_size_opt('%1E')
	assert s.mode == .round_up
	assert s.size == 1 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024

	// TODO: Test u64 overflows
}

fn test_size_calc() {
	assert calc_target_size(777, parse_size_opt('/256'), 1) == 768
	assert calc_target_size(777, parse_size_opt('%256'), 1) == 1024
	assert calc_target_size(777, parse_size_opt('%256K'), 1) == 256 * 1024
	assert calc_target_size(777, parse_size_opt('/256K'), 1) == 0
	assert calc_target_size(777, parse_size_opt('+514'), 1) == 1291
	assert calc_target_size(777, parse_size_opt('-77'), 1) == 700
	assert calc_target_size(777, parse_size_opt('-7777'), 1) == 0
	assert calc_target_size(777, parse_size_opt('+14GB'), 1) == 14_000_000_777
}

fn pairwise_compare(args string, expected_size u64) ! {
	res1 := rig.call_orig('${args} a')
	assert res1.exit_code == 0, "Orig call with '${args} a' fails with output:\n---\n${res1.output}---\n"
	res2 := rig.call_new('${args} b')
	assert res2.exit_code == 0, "New call with '${args} b' fails with output:\n---\n${res2.output}---\n"
	assert os.exists('a') == os.exists('b')
	if os.exists('a') {
		orig := os.stat('a')!
		new := os.stat('b')!
		assert orig.size == new.size, args
		assert new.size == expected_size, args
		assert orig.mode == new.mode, args
	}
}

fn test_compare() {
	assert !os.exists('a')
	assert !os.exists('b')

	pairwise_compare('-s 1024 -c', 0)!
	pairwise_compare('-s 57721', 57721)!
	$if !windows {
		pairwise_compare('-s %1024', 57 * 1024)!
	}
	pairwise_compare('-s /4096', 56 * 1024)!
	pairwise_compare('-s 1024 -c', 1024)!
	pairwise_compare('-s +1K -c', 2048)!
	$if !windows {
		pairwise_compare('-s -2E -c', 0)!
	}
	pairwise_compare('-s ">4KB" -c', 4000)!
	pairwise_compare('-s ">3KB" -c', 4000)!
	pairwise_compare('-s "<2KB" -c', 2000)!
	pairwise_compare('-s "<3KB" -c', 2000)!
	pairwise_compare('-s ">3K" -c', 3072)!

	// We got the tool, might as well use it to make a reference file
	cmd := rig.call_new('-s 42 ref_file')
	assert cmd.exit_code == 0
	assert os.exists('ref_file')
	assert os.stat('ref_file')!.size == 42

	pairwise_compare('-r ref_file -s +3', 45)!
	$if !windows {
		pairwise_compare('-r ref_file -s -2', 40)!
	}
	pairwise_compare('-r ref_file -s "<1MiB"', 42)!
	pairwise_compare('-r ref_file -s ">12KiB"', 12 * 1024)!
	$if !windows {
		pairwise_compare('-r ref_file -s %1K', 1024)!
		pairwise_compare('-r ref_file -s %25', 50)!
	}
	pairwise_compare('-r ref_file -s /32', 32)!

	assert os.exists('a')
	assert os.exists('b')
	os.rm('a')!
	os.rm('b')!
	os.rm('ref_file')!
}

fn test_compare_blocks() {
	assert !os.exists('a')
	assert !os.exists('b')

	// We got the tool, might as well use it to make a reference file
	cmd := rig.call_new('-o -s 42 ref_file')
	assert cmd.exit_code == 0
	assert os.exists('ref_file')

	block_size := get_block_size('ref_file') or { default_block_size }

	// Do not create a file so expected size does not matter
	pairwise_compare('-o -s 1024 -c', 0 * block_size)!
	assert !os.exists('a')
	assert !os.exists('b')

	$if !windows {
		pairwise_compare('-o -s 57721', 57721 * block_size)!
		pairwise_compare('-o -s "%1024"', 57 * 1024 * block_size)!
		pairwise_compare('-o -s /4096', 56 * 1024 * block_size)!
		pairwise_compare('-o -s 1024 -c', 1024 * block_size)!
		pairwise_compare('-o -s +1K -c', 2048 * block_size)!
		pairwise_compare('-o -s ">4KB" -c', 4000 * block_size)!
		pairwise_compare('-o -s ">3KB" -c', 4000 * block_size)!
		pairwise_compare('-o -s "<2KB" -c', 2000 * block_size)!
		pairwise_compare('-o -s "<3KB" -c', 2000 * block_size)!
		pairwise_compare('-o -s ">3K" -c', 3072 * block_size)!
		pairwise_compare('-o -r ref_file -s +3', 45 * block_size)!
		pairwise_compare('-o -r ref_file -s -2', 40 * block_size)!
		pairwise_compare('-o -r ref_file -s "<1MiB"', 42 * block_size)!
		pairwise_compare('-o -r ref_file -s ">12KiB"', 12 * 1024 * block_size)!
		pairwise_compare('-o -r ref_file -s "%1K"', 1024 * block_size)!
		pairwise_compare('-o -r ref_file -s "%25"', 50 * block_size)!
		pairwise_compare('-o -r ref_file -s /32', 32 * block_size)!
		assert os.exists('a')
		assert os.exists('b')
		os.rm('a')!
		os.rm('b')!
	}

	os.rm('ref_file')!
}
