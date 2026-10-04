module main

import os
import common.testing

const rig = testing.prepare_rig(util: 'sort')
const executable_under_test = rig.executable_under_test
const eol = testing.output_eol()

const words_path = os.join_path(rig.temp_dir, 'words.txt')
const numbers_path = os.join_path(rig.temp_dir, 'numbers.txt')
const pairs_path = os.join_path(rig.temp_dir, 'pairs.txt')
const months_path = os.join_path(rig.temp_dir, 'months.txt')
const versions_path = os.join_path(rig.temp_dir, 'versions.txt')
const dups_path = os.join_path(rig.temp_dir, 'dups.txt')
const plain_path = os.join_path(rig.temp_dir, 'plain.txt')
const od_path = os.join_path(rig.temp_dir, 'od.txt')
const sorted_path = os.join_path(rig.temp_dir, 'sorted.txt')

fn testsuite_begin() {
	os.write_lines(words_path, ['banana', 'Apple', 'cherry', 'apple', 'Banana']) or {}
	os.write_lines(numbers_path, ['10', '9', '-5', 'abc', '100', '2']) or {}
	os.write_lines(pairs_path, ['b 2', 'a 10', 'b 1', 'a 2']) or {}
	os.write_lines(months_path, ['JAN', 'jan', 'Feb', 'DEC', 'unknown', 'Mar']) or {}
	os.write_lines(versions_path, ['v1.10', 'v1.9', 'v1.2', 'v10.0']) or {}
	os.write_lines(dups_path, ['dup', 'dup', 'dup', 'other', 'dup']) or {}
	os.write_lines(plain_path, ['b 2', 'a 10', 'b 1', 'a 2']) or {}
	os.write_file(od_path, 'b\0c\nd\0e\n') or {}
	os.write_lines(sorted_path, ['a', 'b', 'c']) or {}
}

fn testsuite_end() {
	os.rm(words_path)!
	os.rm(numbers_path)!
	os.rm(pairs_path)!
	os.rm(months_path)!
	os.rm(versions_path)!
	os.rm(dups_path)!
	os.rm(plain_path)!
	os.rm(od_path)!
	os.rm(sorted_path)!
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

// The byte comparison is the order LC_ALL=C gives, which is what the rig runs
// under, so a plain sort is the uppercase letters before the lower case ones.

fn test_plain_order() {
	res := os.execute('${executable_under_test} ${words_path}')

	assert res.exit_code == 0
	assert res.output == 'Apple${eol}Banana${eol}apple${eol}banana${eol}cherry${eol}'
}

fn test_reverse() {
	res := os.execute('${executable_under_test} -r ${words_path}')

	assert res.exit_code == 0
	assert res.output == 'cherry${eol}banana${eol}apple${eol}Banana${eol}Apple${eol}'
}

// -f folds the case, so the two spellings of a word weigh the same and the
// last-resort comparison puts the upper case first.

fn test_ignore_case() {
	res := os.execute('${executable_under_test} -f ${words_path}')

	assert res.exit_code == 0
	assert res.output == 'Apple${eol}apple${eol}Banana${eol}banana${eol}cherry${eol}'
}

// -n weighs the number at the front. A line with no number weighs zero, which is
// why "abc" lands between -5 and 2.

fn test_numeric() {
	res := os.execute('${executable_under_test} -n ${numbers_path}')

	assert res.exit_code == 0
	assert res.output == '-5${eol}abc${eol}2${eol}9${eol}10${eol}100${eol}'
}

fn test_numeric_reverse() {
	res := os.execute('${executable_under_test} -n -r ${numbers_path}')

	assert res.exit_code == 0
	assert res.output == '100${eol}10${eol}9${eol}2${eol}abc${eol}-5${eol}'
}

// -g reads what strtod does, so it takes an exponent and a hexadecimal float.

fn test_general_numeric() {
	res := os.execute('${executable_under_test} -g ${numbers_path}')

	assert res.exit_code == 0
	assert res.output == 'abc${eol}-5${eol}2${eol}9${eol}10${eol}100${eol}'
}

// -h reads a size suffix, and only the capitals from P upwards.

fn test_human_numeric() {
	list := os.join_path(rig.temp_dir, 'human.txt')
	os.write_lines(list, ['1K', '512', '1M', '2k', '1G', '10']) or {}
	res := os.execute('${executable_under_test} -h ${list}')

	assert res.exit_code == 0
	assert res.output == '10${eol}512${eol}1K${eol}2k${eol}1M${eol}1G${eol}'
	os.rm(list)!
}

fn test_month_sort() {
	res := os.execute('${executable_under_test} -M ${months_path}')

	assert res.exit_code == 0
	assert res.output == 'unknown${eol}JAN${eol}jan${eol}Feb${eol}Mar${eol}DEC${eol}'
}

// -V weighs runs of digits as numbers, so 1.10 comes after 1.9.

fn test_version_sort() {
	res := os.execute('${executable_under_test} -V ${versions_path}')

	assert res.exit_code == 0
	assert res.output == 'v1.2${eol}v1.9${eol}v1.10${eol}v10.0${eol}'
}

// A key weighs one field. The keys here are the second fields as strings, so 1
// comes before 10 before 2.

fn test_key_second_field() {
	res := os.execute('${executable_under_test} -k2,2 ${pairs_path}')

	assert res.exit_code == 0
	assert res.output == 'b 1${eol}a 10${eol}a 2${eol}b 2${eol}'
}

fn test_key_two_keys() {
	res := os.execute('${executable_under_test} -k2,2 -k1,1 ${pairs_path}')

	assert res.exit_code == 0
	assert res.output == 'b 1${eol}a 10${eol}a 2${eol}b 2${eol}'
}

fn test_key_with_numeric_ordering() {
	res := os.execute('${executable_under_test} -k2,2n ${pairs_path}')

	assert res.exit_code == 0
	assert res.output == 'b 1${eol}a 2${eol}b 2${eol}a 10${eol}'
}

// -t names the separator, and it has to be a single character.

fn test_field_separator() {
	list := os.join_path(rig.temp_dir, 'colon.txt')
	os.write_lines(list, ['b:12', 'a:10', 'a:2']) or {}
	res := os.execute('${executable_under_test} -t: -k2,2n ${list}')

	assert res.exit_code == 0
	assert res.output == 'a:2${eol}a:10${eol}b:12${eol}'
	os.rm(list)!
}

fn test_field_separator_rejects_two_characters() {
	res := os.execute('${executable_under_test} -t:: ${pairs_path}')

	assert res.exit_code == 2
	assert res.output.trim_space() == "sort: multi-character tab '::'"
}

// A field number of zero is not a position, so GNU rejects the definition.

fn test_key_zero_field_is_an_error() {
	res := os.execute('${executable_under_test} -k1,0 ${pairs_path}')

	assert res.exit_code == 2
	assert res.output.trim_space() == "sort: field number is zero: invalid field specification '1,0'"
}

// Several files are one stream that is sorted as a whole, not one stream per file.

fn test_several_files_are_one_stream() {
	res := os.execute('${executable_under_test} ${numbers_path} ${words_path}')

	assert res.exit_code == 0
	lines := res.output.trim_space().split('\n')
	assert lines.len == 11
	assert lines[0] == '-5'
	assert lines[10] == 'cherry'
}

// -m promises each input is sorted, so it merges without sorting and a line out
// of place in its own file stays there.

fn test_merge_keeps_unsorted_input_as_it_is() {
	unsorted := os.join_path(rig.temp_dir, 'unsorted.txt')
	os.write_lines(unsorted, ['3', '1', '2']) or {}
	res := os.execute('${executable_under_test} -m ${unsorted}')

	assert res.exit_code == 0
	assert res.output == '3${eol}1${eol}2${eol}'
	os.rm(unsorted)!
}

// -u keeps the first line of a run of equal keys, which with -n means equal
// numbers rather than equal lines.

fn test_unique_by_key_under_numeric() {
	res := os.execute('${executable_under_test} -n -u ${numbers_path}')

	assert res.exit_code == 0
	assert res.output == '-5${eol}abc${eol}2${eol}9${eol}10${eol}100${eol}'
}

fn test_unique_plain() {
	res := os.execute('${executable_under_test} -u ${dups_path}')

	assert res.exit_code == 0
	assert res.output == 'dup${eol}other${eol}'
}

// -s turns off the last-resort comparison, so equal keys keep the order they
// arrived in.

fn test_stable() {
	list := os.join_path(rig.temp_dir, 'stable.txt')
	os.write_lines(list, ['b 1', 'a 2', 'b 0', 'a 1']) or {}
	res := os.execute('${executable_under_test} -s -k1,1 ${list}')

	assert res.exit_code == 0
	assert res.output == 'a 2${eol}a 1${eol}b 1${eol}b 0${eol}'
	os.rm(list)!
}

fn test_without_stable_the_lines_are_reordered() {
	list := os.join_path(rig.temp_dir, 'unstable.txt')
	os.write_lines(list, ['b 1', 'a 2', 'b 0', 'a 1']) or {}
	res := os.execute('${executable_under_test} -k1,1 ${list}')

	assert res.exit_code == 0
	assert res.output == 'a 1${eol}a 2${eol}b 0${eol}b 1${eol}'
	os.rm(list)!
}

// -c names the file, the line and the line itself, and reports the first disorder
// only. -C says nothing.

fn test_check_reports_the_first_disorder() {
	res := os.execute('${executable_under_test} -c ${numbers_path}')

	assert res.exit_code == 1
	assert res.output == 'sort: ${numbers_path}:3: disorder: -5${eol}'
}

fn test_check_quiet_on_a_disorder() {
	res := os.execute('${executable_under_test} -C ${numbers_path}')

	assert res.exit_code == 1
	assert res.output == ''
}

fn test_check_succeeds_on_sorted_input() {
	res := os.execute('${executable_under_test} -c ${sorted_path}')

	assert res.exit_code == 0
	assert res.output == ''
}

// With -c only one input is allowed, because the lines would otherwise have no
// single position to report.

fn test_check_takes_one_file() {
	res := os.execute('${executable_under_test} -c ${numbers_path} ${words_path}')

	assert res.exit_code == 2
	assert res.output.trim_space() == "sort: extra operand '${words_path}' not allowed with -c"
}

fn test_output_to_a_file() {
	out := os.join_path(rig.temp_dir, 'out.txt')
	res := os.execute('${executable_under_test} -o ${out} ${numbers_path}')

	assert res.exit_code == 0
	assert res.output == ''
	assert os.read_file(out)! == '-5\n10\n100\n2\n9\nabc\n'
	os.rm(out)!
}

fn test_reads_standard_input() {
	res := os.execute('cat ${numbers_path} | ${executable_under_test}')

	assert res.exit_code == 0
	assert res.output == '-5${eol}10${eol}100${eol}2${eol}9${eol}abc${eol}'
}

fn test_missing_file() {
	res := os.execute('${executable_under_test} ${rig.temp_dir}/nosuchfile')

	assert res.exit_code == 2
	assert res.output.trim_space().starts_with('sort: cannot read:')
}

// -z makes the NUL the record separator, which is how a file whose names contain
// newlines is sorted.

fn test_zero_terminated() {
	res := os.execute('${executable_under_test} -z ${od_path}')

	assert res.exit_code == 0
	assert res.output == 'b\x00c${eol}d\x00e${eol}\x00'
}

// --files0-from reads the list of names from a file of NUL separated names.

fn test_files0_from() {
	list := os.join_path(rig.temp_dir, 'names')
	os.write_file(list, '${words_path}\x00${numbers_path}\x00') or {}
	res := os.execute('${executable_under_test} --files0-from=${list}')

	assert res.exit_code == 0
	lines := res.output.trim_space().split('\n')
	assert lines.len == 11
	assert lines[0] == '-5'
	os.rm(list)!
}

fn test_unknown_option() {
	res := os.execute('${executable_under_test} --no-such-option ${words_path}')

	assert res.exit_code == 2
	assert res.output.trim_space() == "sort: unrecognized option '--no-such-option'
Try 'sort --help' for more information."
}
