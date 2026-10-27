// Compiled on its own by `v test src/pr/`, so the logic lives in common/pr.
import common.pr as prmod
import os

const input_content = 'one two three four five\nsix seven eight\n'

fn work_dir() string {
	return os.join_path(os.temp_dir(), 'pr_test_tree')
}

fn input_path() string {
	return os.join_path(work_dir(), 'in.txt')
}

fn testsuite_begin() {
	os.rmdir_all(work_dir()) or {}
	os.mkdir_all(work_dir()) or { panic('mkdir: ${err}') }
	os.write_file(input_path(), input_content) or { panic('write: ${err}') }
}

fn testsuite_end() {
	os.rmdir_all(work_dir()) or {}
}

fn run_pr(args []string) string {
	mut files := [][]u8{}
	files << os.read_file_array(input_path())
	return prmod.run(prmod.parse_args(args), files)
}

fn test_no_options_passes_through() {
	assert run_pr([]) == 'one two three four five\nsix seven eight'
}

fn test_number_lines() {
	out := run_pr(['-n'])
	assert out == '    1\tone two three four five\n    2\tsix seven eight'
}

fn test_number_and_double_space() {
	// -d follows every line with a blank, including the last one.
	out := run_pr(['-n', '-d'])
	assert out == '    1\tone two three four five\n\n    2\tsix seven eight\n'
}

fn test_first_line_number() {
	assert run_pr(['-n', '-N', '5']).starts_with('    5\t')
	assert run_pr(['-n', '-N', '5']).contains('\n    6\t')
}

fn test_indent() {
	out := run_pr(['-o', '4'])
	assert out == '    one two three four five\n    six seven eight'
}

fn test_parse_args_defaults() {
	s := prmod.parse_args([])
	assert s.page_length == 66
	assert s.page_width == 72
	assert s.columns == 1
	assert s.first_number == 1
	assert !s.no_header
}

fn test_parse_args_flags() {
	s := prmod.parse_args(['-t', '-n', '-d'])
	assert s.no_header
	assert s.number_lines
	assert s.double_space

	long := prmod.parse_args(['--omit-header', '--number-lines', '--double-space'])
	assert long.no_header
	assert long.number_lines
	assert long.double_space
}

fn test_parse_args_page_geometry() {
	s := prmod.parse_args(['-l', '40', '-w', '100'])
	assert s.page_length == 40
	assert s.page_width == 100

	from_equals := prmod.parse_args(['--length=30', '--width=80'])
	assert from_equals.page_length == 30
	assert from_equals.page_width == 80
}

fn test_parse_args_operands_and_separator() {
	s := prmod.parse_args(['-t', 'a', 'b'])
	assert s.operands == ['a', 'b']

	dashdash := prmod.parse_args(['-t', '--', '-weird'])
	assert dashdash.operands == ['-weird']
}

fn test_columns_from_a_leading_digit() {
	// Columns come from -N, where N is a digit; a bare digit is a file
	// operand, which is exactly what GNU does. When both appear the option
	// wins and the file stays an operand.
	s := prmod.parse_args(['-2', 'file'])
	assert s.columns == 2
	assert s.operands == ['file']

	bare := prmod.parse_args(['2'])
	assert bare.columns == 1
	assert bare.operands == ['2']
}

fn test_trailing_newline_is_a_terminator_not_a_line() {
	// A file ending in a newline has that many lines, not one more, so the
	// last output line is the final line of content rather than a blank.
	out := run_pr(['-n'])
	assert !out.ends_with('\n\n')
	assert out.ends_with('six seven eight')
}
