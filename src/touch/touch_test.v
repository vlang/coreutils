module main

import os
import time

fn temp_file_name() string {
	dir := os.temp_dir()
	file := '${dir}/t${time.ticks()}' 
	return file
}

fn p(msg string) {
	print('${msg:-50}')
}

fn pass() {
	println('✅')
}

fn test_touch_one_file_no_options() {
	p('test_touch_one_file_no_options')
	file := temp_file_name()
	assert(!os.exists(file))
	touch(['touch', file])
	assert(os.exists(file))
	os.rm(file)!
	pass()
}

fn test_touch_two_files_no_options() {
	p('test_touch_two_files_no_options')
	file1 := temp_file_name()
	file2 := file1 + 'x'
	assert(!os.exists(file1))
	assert(!os.exists(file2))
	touch(['touch', file1, file2])
	assert(os.exists(file1))
	assert(os.exists(file2))
	os.rm(file1)!
	os.rm(file2)!
	pass()
}

fn test_touch_no_create_option() {
	p('test_touch_no_create_option')
	file := temp_file_name()
	touch(['touch', '-c', file])
	assert(!os.exists(file))
	pass()
}