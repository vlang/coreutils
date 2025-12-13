module main

import os
import time

fn temp_file_name() string {
	dir := os.temp_dir()
	file := '${dir}/t${time.ticks()}'
	return file
}

fn p(msg string) {
	println(msg)
}

fn pass() {
	assert true
}

fn test_touch_one_file_no_options() {
	p(@METHOD)
	file := temp_file_name()
	assert !os.exists(file)
	touch(['touch', file])
	assert os.exists(file)
	os.rm(file)!
	pass()
}

fn test_touch_two_files_no_options() {
	p(@METHOD)
	file1 := temp_file_name()
	file2 := file1 + 'x'
	assert !os.exists(file1)
	assert !os.exists(file2)
	touch(['touch', file1, file2])
	assert os.exists(file1)
	assert os.exists(file2)
	os.rm(file1)!
	os.rm(file2)!
	pass()
}

fn test_touch_no_create_option() {
	p(@METHOD)
	file := temp_file_name()
	touch(['touch', '-c', file])
	assert !os.exists(file)
	pass()
}

fn test_touch_create_with_d_option() {
	p(@METHOD)
	file := temp_file_name()
	date := '2022-12-01T11:00:01'
	unix := time.parse_iso8601(date)!.unix()
	touch(['touch', '-d', date, file])
	stat := os.lstat(file)!
	assert stat.atime == unix
	assert stat.mtime == unix
	os.rm(file)!
	pass()
}

fn test_touch_create_with_a_d_option() {
	p(@METHOD)
	file := temp_file_name()
	date := '2022-12-01T11:00:01'
	unix := time.parse_iso8601(date)!.unix()
	touch(['touch', '-a', '-d', date, file])
	stat := os.lstat(file)!
	assert stat.atime == unix
	assert stat.mtime != unix
	os.rm(file)!
	pass()
}

fn test_touch_create_with_m_d_option() {
	p(@METHOD)
	file := temp_file_name()
	date := '2022-12-01T11:00:01'
	unix := time.parse_iso8601(date)!.unix()
	touch(['touch', '-m', '-d', date, file])
	stat := os.lstat(file)!
	assert stat.atime != unix
	assert stat.mtime == unix
	os.rm(file)!
	pass()
}

fn test_touch_with_reference_file() {
	p(@METHOD)
	rfile := temp_file_name()
	mdate := '2022-12-01T11:00:01'
	mtime := time.parse_iso8601(mdate)!.unix()
	touch(['touch', '-d', mdate, rfile])

	adate := '2022-12-01T11:50:02'
	atime := time.parse_iso8601(adate)!.unix()
	touch(['touch', '-a', '-d', adate, rfile])

	file := rfile + 'x'
	touch(['touch', '-r', rfile, file])

	stat := os.lstat(file)!
	assert stat.atime == atime
	assert stat.mtime == mtime

	os.rm(file)!
	os.rm(rfile)!
	pass()
}

fn test_touch_no_reference_option() {
	p(@METHOD)
	file := temp_file_name()
	fdate := '2022-12-01T11:00:01'
	ftime := time.parse_iso8601(fdate)!.unix()
	touch(['touch', '-d', fdate, file])

	// confirm correct start state
	stat := os.lstat(file)!
	assert stat.atime == ftime
	assert stat.mtime == ftime

	if os.user_os() == 'windows' {
		eprintln('skip symlink checks on windows, they need administrative permissions')
		return
	}

	link := file + 'lnk'
	os.symlink(file, link)!

	// touch the symlink
	ldate := '2023-01-01T20:00:35'
	ltime := time.parse_iso8601(ldate)!.unix()
	touch(['touch', '-h', '-d', ldate, link])

	// check original file
	fstat := os.lstat(file)!
	assert fstat.atime == ftime
	assert fstat.mtime == ftime

	// lstat does not 'follow' links
	lstat := os.lstat(link)!
	assert lstat.atime == ltime
	assert lstat.mtime == ltime

	os.rm(link)!
	os.rm(file)!
	pass()
}
