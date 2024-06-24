module main

import os

fn test_chunks() {
	assert chunks('XXX_temp_XXXX_XXX_XX.txt') == ['XXX', '_temp_', 'XXXX', '_', 'XXX', '_', 'XX',
		'.txt']
}

fn test_no_option_creates_file() {
	options := Options{}
	file := mktemp(options)
	assert os.exists(file)
}

fn test_directory_option() {
	options := Options{
		directory: true
	}
	dir := mktemp(options)
	assert os.is_dir(dir)
}
