module main

import os
import time

fn write_tmp_file(content string) string {
	tmp := '${os.temp_dir()}/${tmp_pattern}${time.ticks()}'
	os.write_file(tmp, content) or { panic(err) }
	return tmp
}

fn test_1() {
	file := write_tmp_file('        a       b       c\n')
	res := os.execute('unexpand ${file}')
	assert res.output.bytes() == [u8(9), 97, 32, 32, 32, 32, 32, 32, 32, 98, 32, 32, 32, 32, 32,
		32, 32, 99, 10]
}

fn test_2() {
	file := write_tmp_file('a\tb\tc\td\te\tf\n')
	res := os.execute('unexpand -t 3,+7 ${file}')
	assert res.output.bytes() == [u8(97), 9, 98, 9, 99, 9, 100, 9, 101, 9, 102, 10]

	// [u8(117), 110, 101, 120, 112, 97, 110, 100, 58, 32, 98, 97, 100,
	// 	32, 116, 97, 98, 32, 115, 116, 111, 112, 32, 115, 112, 101, 99, 10]
}

fn test_3() {
	file := write_tmp_file('a\tb\tc\td\te\tf\n')
	res := os.execute('unexpand -t 3,/7 ${file}')
	assert res.output.bytes() == [u8(97), 9, 98, 9, 99, 9, 100, 9, 101, 9, 102, 10]

	// [u8(117), 110, 101, 120, 112, 97, 110, 100, 58, 32, 98, 97, 100,
	// 	32, 116, 97, 98, 32, 115, 116, 111, 112, 32, 115, 112, 101, 99, 10]
}

fn test_4() {
	file := write_tmp_file('a  b   c d e\n')
	res := os.execute('unexpand -t 3,7 ${file}')
	assert res.output.bytes() == [u8(97), 9, 98, 9, 99, 32, 100, 32, 101, 10]
}

fn test_5() {
	file := write_tmp_file('cart\bd    bard\n')
	res := os.execute('unexpand -a ${file}')
	assert res.output.bytes() == [u8(99), 97, 114, 116, 8, 100, 9, 98, 97, 114, 100, 10]
}
