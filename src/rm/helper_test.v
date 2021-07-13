module main

import os

fn test_valid_yes() {
	// assert 1==2
	assert valid_yes('y')
	assert valid_yes('Y')
	assert valid_yes('Yes')
	assert valid_yes('yes')
	assert valid_yes('YE')
	assert valid_yes('YASS')
	assert valid_yes('YES!!!!')

	assert !valid_yes('NO')
	assert !valid_yes('n')
	assert !valid_yes('no.. yes')
}

fn test_valid_setup_rm() ? {
	args_no_flags := ['rm']
	args_r := ['rm', '-r', 'a']
	args_r_i_v := ['rm', '--recursive', '-i', '--verbose', 'a', 'b']
	args_f_ic_v := ['rm', '-f', '-I', '-v', 'a', 'b']
	args_rc_f_i_ic := ['rm', '--force', '--interactive=always', '-I', '-R', 'c']

	rm1, files1 := setup_rm_command(args_no_flags) or {
		rm2, files2 := setup_rm_command(args_r) ?
		rm3, files3 := setup_rm_command(args_r_i_v) ?
		rm4, files4 := setup_rm_command(args_f_ic_v) ?
		rm5, files5 := setup_rm_command(args_rc_f_i_ic) ?

		expect_rm2 := RmCommand{
			recursive: true
		}
		expect_rm3 := RmCommand{
			recursive: true
			interactive: true
			verbose: true
		}
		expect_rm4 := RmCommand{
			force: true
			less_int: true
			verbose: true
		}
		expect_rm5 := RmCommand{
			recursive: true
			force: true
			interactive: true
			less_int: true
		}

		// println(expect_rm2)
		// println(expect_rm3)
		// println(expect_rm4)
		// println(expect_rm5)
		assert rm2 == expect_rm2
		assert rm3 == expect_rm3
		assert rm4 == expect_rm4
		assert rm5 == expect_rm5

		expect_files2 := ['a']
		expect_files3 := ['a', 'b']
		expect_files4 := ['a', 'b']
		expect_files5 := ['c']

		assert files2 == expect_files2
		assert files3 == expect_files3
		assert files4 == expect_files4
		assert files5 == expect_files5

		return
	}
	assert false
}

fn test_run_rm() ? {
	path := 'a'
	os.create(path) ?
	assert os.exists(path)
	args := ['rm', path]
	run_rm(args)
	assert !os.exists(path)

	dir := 'dir'
	os.mkdir(dir) ?
	assert os.exists(dir)
	args_dir := ['rm', dir]
	run_rm(args_dir)
	assert os.exists(dir)
	args_dir_right := ['rm', '-d', dir]
	run_rm(args_dir_right)
	assert !os.exists(dir)
}
