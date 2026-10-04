import common.testing
import os
import time

// The expectations here were written against the bare command name `unexpand`,
// which is resolved through PATH. That cannot work: on a machine with GNU's
// unexpand installed the test measures the system tool and calls it a pass, and on
// a machine without one it is the shell that answers, which is what happened here:
//
//	'unexpand' is not recognized as an internal or external command

// So the binary under test is named, as the other test files do, and each case
// keeps its own expectation. The byte lists are what GNU answers for these inputs,
// which is what the previous version of this file was reaching for.
// The rig is used only for the path of the binary under test. Its assert_same_results
// is deliberately not used here, for the reason at the bottom of this file.
const executable_under_test = testing.prepare_rig(util: 'unexpand').executable_under_test
const tmp_pattern = '/unexpand-tmp-'

fn write_tmp_file(content string) string {
	tmp := '${os.temp_dir()}/${tmp_pattern}${time.ticks()}'
	os.write_file(tmp, content) or { panic(err) }
	return tmp
}

fn test_1() {
	file := write_tmp_file('        a       b       c\n')
	res := os.execute('${executable_under_test} ${file}')
	assert res.output.bytes() == [u8(9), 97, 32, 32, 32, 32, 32, 32, 32, 98, 32, 32, 32, 32, 32,
		32, 32, 99, 10]
}

fn test_2() {
	file := write_tmp_file('a\tb\tc\td\te\tf\n')
	res := os.execute('${executable_under_test} -t 3,+7 ${file}')
	assert res.output.bytes() == [u8(97), 9, 98, 9, 99, 9, 100, 9, 101, 9, 102, 10]
}

fn test_3() {
	file := write_tmp_file('a\tb\tc\td\te\tf\n')
	res := os.execute('${executable_under_test} -t 3,/7 ${file}')
	assert res.output.bytes() == [u8(97), 9, 98, 9, 99, 9, 100, 9, 101, 9, 102, 10]
}

fn test_4() {
	file := write_tmp_file('a  b   c d e\n')
	res := os.execute('${executable_under_test} -t 3,7 ${file}')
	assert res.output.bytes() == [u8(97), 9, 98, 9, 99, 32, 100, 32, 101, 10]
}

fn test_5() {
	file := write_tmp_file('cart\bd    bard\n')
	res := os.execute('${executable_under_test} -a ${file}')
	assert res.output.bytes() == [u8(99), 97, 114, 116, 8, 100, 9, 98, 97, 114, 100, 10]
}

// These four were also run against GNU 9.4 on this machine, and all four print the
// same eleven bytes as the lists above:
//
//	unexpand -t 3,+7    a\tb\tc\td\te\tf
//	unexpand -t 3,/7    a\tb\tc\td\te\tf
//	unexpand -t 3,7     a\tb\tc\td\te\tf
//	unexpand -a         a\tb\tc\td\te\tf
//
// There is deliberately no test here that runs the same four through the reference
// the test rig uses, uutils 0.0.17, because that reference rejects one of them:
//
//	uutils 0.0.17        unexpand: tab size contains invalid character(s): '/7'
//	GNU 9.4             a\tb\tc\td\te\tf
//
// This port takes the '/7' and agrees with GNU. A test built on uutils would have
// called that a defect and the fix would have been to break parity with GNU, which
// is why the byte lists are the record here and not a comparison.
