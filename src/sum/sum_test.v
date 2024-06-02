module main

import os

fn testsuite_begin() {
	os.chdir(os.dir(@FILE))!
}

fn test_bsd() {
	assert sum('test.txt', false) == '38039     1 test.txt'
}

fn test_sysv() {
	assert sum('test.txt', true) == '25426     1 test.txt'
}
