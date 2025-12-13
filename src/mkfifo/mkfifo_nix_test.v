import os
import common.testing

const rig = testing.prepare_rig(util: util)
const tfolder = os.join_path(os.temp_dir(), 'coreutils', 'mkfifo_test')

const util = 'mkfifo'
const platform_util = util

const executable_under_test = testing.prepare_executable(util)
const cmd = testing.new_paired_command(platform_util, executable_under_test)

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn testsuite_begin() {
	rig.assert_platform_util()
	os.chdir(testing.temp_folder)!
	eprintln('testsuite_begin, tfolder = ${tfolder}')
	os.rmdir_all(tfolder) or {}
	assert !os.is_dir(tfolder)
	os.mkdir_all(tfolder) or { panic(err) }
	os.chdir(tfolder) or {}
	assert os.is_dir(tfolder)
}

fn testsuite_end() {
	os.chdir(os.wd_at_startup) or {}
	os.rmdir_all(tfolder) or {}
	assert !os.is_dir(tfolder)
	eprintln('testsuite_end  , tfolder = ${tfolder} removed.')
}

fn test_default_create_single_pipe() {
	target := 'test_piped'
	res := os.execute('${executable_under_test} ${target}')
	assert res.exit_code == 0
	assert res.output.trim_space() == ''
	assert os.is_file(target)
	st := os.stat(target)!
	assert st.get_filetype() == os.FileType.fifo
}

fn test_default_create_multiple_pipes() {
	target := 'tp1 tp2 tp3'
	res := os.execute('${executable_under_test} ${target}')
	assert res.exit_code == 0
	assert res.output.trim_space() == ''
	for p in target.split(' ') {
		assert os.is_file(p)
		st := os.stat(p)!
		assert st.get_filetype() == os.FileType.fifo
	}
}
