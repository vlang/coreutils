import common.testing
import os

const rig = testing.prepare_rig(util: 'comm')
const executable_under_test = rig.executable_under_test

fn testsuite_begin() {
	rig.assert_platform_util()
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

fn test_comm_basic() {
	// Create test files
	file1_path := os.temp_dir() + '/comm_test1.txt'
	file2_path := os.temp_dir() + '/comm_test2.txt'

	os.write_lines(file1_path, ['apple', 'banana', 'cherry', 'date'])!
	os.write_lines(file2_path, ['banana', 'cherry', 'date', 'fig'])!

	// Test basic functionality
	res := os.execute('${executable_under_test} ${file1_path} ${file2_path}')
	assert res.exit_code == 0

	// Normalize line endings for cross-platform compatibility
	output := res.output.replace('\r\n', '\n')
	expected := 'apple\n\t\tbanana\n\t\tcherry\n\t\tdate\n\tfig\n'
	assert output == expected

	// Compare with platform util
	rig.assert_same_results('${file1_path} ${file2_path}')

	// Cleanup
	os.rm(file1_path)!
	os.rm(file2_path)!
}

fn test_comm_suppress_columns() {
	file1_path := os.temp_dir() + '/comm_test3.txt'
	file2_path := os.temp_dir() + '/comm_test4.txt'

	os.write_lines(file1_path, ['a', 'b', 'c'])!
	os.write_lines(file2_path, ['b', 'c', 'd'])!

	// Test -1 flag
	res1 := os.execute('${executable_under_test} -1 ${file1_path} ${file2_path}')
	assert res1.exit_code == 0
	assert res1.output.replace('\r\n', '\n') == '\tb\n\tc\nd\n'

	// Test -2 flag
	res2 := os.execute('${executable_under_test} -2 ${file1_path} ${file2_path}')
	assert res2.exit_code == 0
	assert res2.output.replace('\r\n', '\n') == 'a\n\tb\n\tc\n'

	// Test -3 flag
	res3 := os.execute('${executable_under_test} -3 ${file1_path} ${file2_path}')
	assert res3.exit_code == 0
	assert res3.output.replace('\r\n', '\n') == 'a\n\td\n'

	// Test -12 (show only common)
	res12 := os.execute('${executable_under_test} -12 ${file1_path} ${file2_path}')
	assert res12.exit_code == 0
	assert res12.output.replace('\r\n', '\n') == 'b\nc\n'

	// Compare with platform util
	rig.assert_same_results('-1 ${file1_path} ${file2_path}')
	rig.assert_same_results('-2 ${file1_path} ${file2_path}')
	rig.assert_same_results('-3 ${file1_path} ${file2_path}')
	rig.assert_same_results('-12 ${file1_path} ${file2_path}')

	// Cleanup
	os.rm(file1_path)!
	os.rm(file2_path)!
}

fn test_comm_empty_files() {
	empty_file := os.temp_dir() + '/comm_empty.txt'
	nonempty_file := os.temp_dir() + '/comm_nonempty.txt'

	os.write_file(empty_file, '')!
	os.write_lines(nonempty_file, ['hello', 'world'])!

	// Both files empty
	res1 := os.execute('${executable_under_test} ${empty_file} ${empty_file}')
	assert res1.exit_code == 0
	assert res1.output == ''

	// First file empty
	res2 := os.execute('${executable_under_test} ${empty_file} ${nonempty_file}')
	assert res2.exit_code == 0
	assert res2.output.replace('\r\n', '\n') == '\thello\n\tworld\n'

	// Second file empty
	res3 := os.execute('${executable_under_test} ${nonempty_file} ${empty_file}')
	assert res3.exit_code == 0
	assert res3.output.replace('\r\n', '\n') == 'hello\nworld\n'

	// Compare with platform util
	rig.assert_same_results('${empty_file} ${empty_file}')
	rig.assert_same_results('${empty_file} ${nonempty_file}')
	rig.assert_same_results('${nonempty_file} ${empty_file}')

	// Cleanup
	os.rm(empty_file)!
	os.rm(nonempty_file)!
}

fn test_comm_stdin() {
	// Skip stdin test on Windows due to pipe command issues
	$if windows {
		return
	}

	file_path := os.temp_dir() + '/comm_stdin_test.txt'
	stdin_file := os.temp_dir() + '/comm_stdin_content.txt'

	os.write_lines(file_path, ['apple', 'banana'])!
	os.write_lines(stdin_file, ['banana', 'cherry'])!

	// Test stdin as first file
	res1 := os.execute('cat ${stdin_file} | ${executable_under_test} - ${file_path}')
	assert res1.exit_code == 0
	// stdin has: banana, cherry
	// file_path has: apple, banana
	// So: apple is only in file2 (1 tab), banana is in both (2 tabs), cherry is only in file1 (0 tabs)
	expected1 := '\tapple\n\t\tbanana\ncherry\n'
	assert res1.output.replace('\r\n', '\n') == expected1

	// Test stdin as second file
	res2 := os.execute('cat ${stdin_file} | ${executable_under_test} ${file_path} -')
	assert res2.exit_code == 0
	expected2 := 'apple\n\t\tbanana\n\tcherry\n'
	assert res2.output.replace('\r\n', '\n') == expected2

	// Cleanup
	os.rm(file_path)!
	os.rm(stdin_file)!
}

fn test_comm_missing_file() {
	// Missing file should produce error
	res := os.execute('${executable_under_test} /nonexistent/file1 /nonexistent/file2')
	assert res.exit_code == 1
	// Error message varies by platform, but should contain the filename
	assert res.output.contains('/nonexistent/file1') || res.output.contains('\\nonexistent\\file1')
}

fn test_comm_missing_operand() {
	// No arguments should produce error
	res1 := os.execute('${executable_under_test}')
	assert res1.exit_code == 1
	assert res1.output.contains('missing operand')

	// One argument should produce error
	res2 := os.execute('${executable_under_test} /tmp/file1')
	assert res2.exit_code == 1
	assert res2.output.contains('missing operand')
}

fn test_comm_delimiter() {
	file1_path := os.temp_dir() + '/comm_delim1.txt'
	file2_path := os.temp_dir() + '/comm_delim2.txt'

	os.write_lines(file1_path, ['a', 'c'])!
	os.write_lines(file2_path, ['b', 'c'])!

	// Test custom delimiter
	res := os.execute('${executable_under_test} --output-delimiter="|" ${file1_path} ${file2_path}')
	assert res.exit_code == 0
	assert res.output.replace('\r\n', '\n') == 'a\n|b\n||c\n'

	// Compare with platform util (if it supports this option)
	// Note: Some platform utils may not support --output-delimiter

	// Cleanup
	os.rm(file1_path)!
	os.rm(file2_path)!
}
