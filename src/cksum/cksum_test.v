import common.testing
import os

const rig = testing.prepare_rig(util: 'cksum')
const executable_under_test = rig.executable_under_test
// GNU writes a bare LF to stdout and stderr on every platform, Windows included,
// so this is not common's eol. Measured here, each of these utilities ends its
// output with byte 10 and not with 13,10:
//
//	cksum, wc, sum, mkdir -v, head
//
// With common's eol the expectations were disagreeing by one byte per line on
// Windows, which is what  test . has been reporting as a content difference.
const eol = '\n'
const test1_txt_path = os.join_path(rig.temp_dir, 'test1.txt')
const test2_txt_path = os.join_path(rig.temp_dir, 'test2.txt')
const test3_txt_path = os.join_path(rig.temp_dir, 'test3.txt')
const empty_path = os.join_path(rig.temp_dir, 'empty.txt')
const dummy = os.join_path(rig.temp_dir, 'dummy')
const long_over_16k = os.join_path(rig.temp_dir, 'long_over_16k')
const long_under_16k = os.join_path(rig.temp_dir, 'long_under_16k')

fn testsuite_begin() {
	rig.assert_platform_util()
	os.write_file(test1_txt_path, 'Hello World!\nHow are you?')!
	os.write_file(test2_txt_path, 'a'.repeat(128 * 1024 + 5))!
	os.write_file(test3_txt_path, 'a'.repeat(3))!
	os.write_file(empty_path, '')!
}

fn testsuite_end() {
	os.rm(test1_txt_path)!
	os.rm(test2_txt_path)!
	os.rm(test3_txt_path)!
	os.rm(empty_path)!
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

// Standard input cannot be fed from a test on Windows.
//
// The test used to say `cat path | cksum`, which is a command line and not a pipe
// there: there is no cat, so the shell answered with exit 255 and the test was
// reporting a failure in a utility it never reached. Going through `cmd /c type`
// instead does not work either, because os.exec quotes each argument and cmd then
// sees a quoted pipe as part of a filename:
//
//	The filename, directory name, or volume label syntax is incorrect.
//
// So the tests that need standard input say so and return, rather than failing for
// a reason that has nothing to do with cksum. The ones that pass a file work here
// and are not skipped.
fn no_standard_input_here() bool {
	$if windows {
		println('feeding standard input from a test needs a pipe this platform has not got, skipping')
		return true
	}
	return false
}

fn test_stdin() {
	if no_standard_input_here() {
		return
	}
	res := os.exec(testing.split_args('cat ${test1_txt_path} | ${executable_under_test}'))

	assert res.exit_code == 0
	assert res.output.trim_space() == '365965416 25'
}

fn test_file_not_exist() {
	res := os.exec(testing.split_args('${executable_under_test} abcd'))

	assert res.exit_code == 1
	assert res.output.trim_space() == 'cksum: abcd: No such file or directory'
}

fn test_one_file() {
	res := os.exec(testing.split_args('${executable_under_test} ${test1_txt_path}'))

	assert res.exit_code == 0
	assert res.output == '365965416 25 ${test1_txt_path}${eol}'
}

fn test_several_files() {
	res := os.exec(testing.split_args('${executable_under_test} ${test1_txt_path} ${test2_txt_path}'))

	assert res.exit_code == 0
	assert res.output == '365965416 25 ${test1_txt_path}${eol}1338884673 131077 ${test2_txt_path}${eol}'
}

// The numeric algorithms each have their own checksum and block size, matching
// GNU: sysv counts bytes, bsd rotates its accumulator, and crc is the POSIX one.

fn test_sysv_checksum() {
	res := os.execute('${executable_under_test} -a sysv ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == '2185 1 ${test1_txt_path}${eol}'
}

fn test_bsd_checksum() {
	res := os.execute('${executable_under_test} -a bsd ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == '59852     1 ${test1_txt_path}${eol}'
}

fn test_crc_checksum() {
	res := os.execute('${executable_under_test} -a crc ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == '365965416 25 ${test1_txt_path}${eol}'
}

// The byte digests default to GNU's tagged form.

fn test_md5_tagged_by_default() {
	res := os.execute('${executable_under_test} -a md5 ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == 'MD5 (${test1_txt_path}) = 9b5ef2ccfe3856698a6729f31b9e0071${eol}'
}

fn test_untagged_digest() {
	res := os.execute('${executable_under_test} -a sha256 --untagged ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output ==
		'7ea13b762c7b42138a17be9aaa8e71cbbdc8604750fb59e3d346a5715252bf09  ${test1_txt_path}${eol}'
}

fn test_sm3_digest() {
	res := os.execute('${executable_under_test} -a sm3 ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output ==
		'SM3 (${test1_txt_path}) = b995b196231877a750f608e124d453461856e6f62b967f1bc2d0647e0e86e8eb${eol}'
}

fn test_blake2b_digest() {
	res := os.execute('${executable_under_test} -a blake2b ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output ==
		'BLAKE2b (${test1_txt_path}) = d08077abe49be879ae79b62cce8be243f1e5555c151a61b458ef5db8fa55909eede6e572f86ad28c72139b6f12b81db465d374d0622b934b7611320d420408e5${eol}'
}

// BLAKE2b is the only algorithm whose digest length can be chosen, and it is
// recorded in the tag when it is not the maximum.

fn test_blake2b_length() {
	res := os.execute('${executable_under_test} -a blake2b -l 128 ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output == 'BLAKE2b-128 (${test1_txt_path}) = 547dd9f46197e32f38f9dbbd835f2a6c${eol}'
}

fn test_length_rejected_for_other_algorithms() {
	res := os.execute('${executable_under_test} -a md5 -l 128 ${test1_txt_path}')

	assert res.exit_code == 1
	assert res.output.trim_space() == 'cksum: --length is only supported with --algorithm=blake2b'
}

fn test_length_must_be_multiple_of_eight() {
	res := os.execute('${executable_under_test} -a blake2b -l 7 ${test1_txt_path}')

	assert res.exit_code == 1
	assert res.output == 'cksum: invalid length: ‘7’${eol}cksum: length is not a multiple of 8${eol}'
}

fn test_empty_file() {
	res := os.execute('${executable_under_test} -a md5 ${empty_path}')

	assert res.exit_code == 0
	assert res.output == 'MD5 (${empty_path}) = d41d8cd98f00b204e9800998ecf8427e${eol}'
}

// --raw prints the binary digest for the byte algorithms, and raw bytes for the
// numeric ones.

fn test_raw_digest() {
	res := os.execute('${executable_under_test} -a md5 --raw ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output.trim_space().len > 0
}

fn test_base64_digest() {
	res := os.execute('${executable_under_test} -a md5 --base64 ${test1_txt_path}')

	assert res.exit_code == 0
	assert res.output ==
		'MD5 (${test1_txt_path}) = m17yzP44VmmKZynzG54AcQ==${eol}'
}

fn test_unknown_algorithm() {
	res := os.execute('${executable_under_test} -a nope ${test1_txt_path}')

	assert res.exit_code == 1
	assert res.output.contains('invalid argument ‘nope’ for ‘--algorithm’')
}

// --check takes the digest to use from the list itself, unless --algorithm names
// one explicitly.

fn test_check_accepts_matching_list() {
	list := os.join_path(rig.temp_dir, 'ok.md5')
	os.write_file(list, 'MD5 (${test1_txt_path}) = 9b5ef2ccfe3856698a6729f31b9e0071${eol}')!
	res := os.execute('${executable_under_test} -c ${list}')

	assert res.exit_code == 0
	assert res.output == '${test1_txt_path}: OK${eol}'
	os.rm(list)!
}

fn test_check_reports_mismatch() {
	list := os.join_path(rig.temp_dir, 'bad.md5')
	os.write_file(list, 'MD5 (${test1_txt_path}) = 0123456789abcdef0123456789abcdef${eol}')!
	res := os.execute('${executable_under_test} -c ${list}')

	assert res.exit_code == 1
	assert res.output == '${test1_txt_path}: FAILED${eol}cksum: WARNING: 1 computed checksum did NOT match${eol}'
	os.rm(list)!
}

fn test_check_status_is_silent() {
	list := os.join_path(rig.temp_dir, 'status.md5')
	os.write_file(list, 'MD5 (${test1_txt_path}) = 0123456789abcdef0123456789abcdef${eol}')!
	res := os.execute('${executable_under_test} -c --status ${list}')

	assert res.exit_code == 1
	assert res.output == ''
	os.rm(list)!
}

// GNU only reads its own tagged form, and requires the recorded digest to be
// exactly as long as the named algorithm produces.

fn test_check_rejects_untagged_list() {
	list := os.join_path(rig.temp_dir, 'untagged.txt')
	os.write_file(list, '365965416 25 ${test1_txt_path}${eol}')!
	res := os.execute('${executable_under_test} -c ${list}')

	assert res.exit_code == 1
	assert res.output.contains('no properly formatted checksum lines found')
	os.rm(list)!
}

fn test_check_rejects_wrong_digest_length() {
	list := os.join_path(rig.temp_dir, 'long.md5')
	os.write_file(
		list,
		'MD5 (${test1_txt_path}) = 9b5ef2ccfe3856698a6729f31b9e0071aa${eol}',
	)!
	res := os.execute('${executable_under_test} -c ${list}')

	assert res.exit_code == 1
	assert res.output.contains('no properly formatted checksum lines found')
	os.rm(list)!
}

fn test_check_missing_file() {
	list := os.join_path(rig.temp_dir, 'missing.md5')
	os.write_file(
		list,
		'MD5 (${os.join_path(rig.temp_dir, 'nosuch.txt')}) = d41d8cd98f00b204e9800998ecf8427e${eol}',
	)!
	res := os.execute('${executable_under_test} -c ${list}')

	assert res.exit_code == 1
	assert res.output.contains('1 listed file could not be read')
	os.rm(list)!
}

// A list written by --base64 is accepted as well, since GNU recognises the
// encoding from the recorded digest.

fn test_check_base64_list() {
	list := os.join_path(rig.temp_dir, 'b64.md5')
	os.write_file(list, 'MD5 (${test1_txt_path}) = m17yzP44VmmKZynzG54AcQ==${eol}')!
	res := os.execute('${executable_under_test} -c ${list}')

	assert res.exit_code == 0
	assert res.output == '${test1_txt_path}: OK${eol}'
	os.rm(list)!
}

// --algorithm given explicitly restricts which tagged lines are accepted.

fn test_check_algorithm_must_match_list() {
	list := os.join_path(rig.temp_dir, 'sha256.md5')
	os.write_file(
		list,
		'SHA256 (${test1_txt_path}) = 7ea13b762c7b42138a17be9aaa8e71cbbdc8604750fb59e3d346a5715252bf09${eol}',
	)!
	res := os.execute('${executable_under_test} -c -a md5 ${list}')

	assert res.exit_code == 1
	assert res.output.contains('no properly formatted checksum lines found')
	os.rm(list)!
}

// A file name that would break the one record per line rule is escaped in a list,
// with the line marked by a leading backslash, and --zero turns that off.

fn test_escapes_newline_in_name() {
	odd := os.join_path(rig.temp_dir, 'two\nlines')
	os.write_file(odd, 'x')!
	res := os.execute("${executable_under_test} -a md5 '${odd}'")

	assert res.exit_code == 0
	assert res.output == '\\MD5 (${escaped_name(odd)}) = 9dd4e461268c8034f5c8564e155c67a6${eol}'
	os.rm(odd)!
}

fn test_zero_disables_name_escaping() {
	odd := os.join_path(rig.temp_dir, 'two\nlines')
	os.write_file(odd, 'x')!
	res := os.execute("${executable_under_test} -a md5 -z '${odd}'")

	assert res.exit_code == 0
	// The record ends with a NUL, and the name is left as it stands.
	assert res.output == 'MD5 (${odd}) = 9dd4e461268c8034f5c8564e155c67a6\x00'
	os.rm(odd)!
}

// escaped_name is how the name above has to appear in a list: the newline written
// as two characters.
fn escaped_name(name string) string {
	return name.replace('\n', '\\n')
}

// A list written with an escaped name has to read back as the real name.

fn test_check_unescapes_name() {
	odd := os.join_path(rig.temp_dir, 'two\nlines')
	os.write_file(odd, 'x')!
	list := os.join_path(rig.temp_dir, 'escaped.md5')
	os.write_file(list,
		'\\MD5 (${escaped_name(odd)}) = 9dd4e461268c8034f5c8564e155c67a6${eol}')!
	res := os.execute('${executable_under_test} -c ${list}')

	assert res.exit_code == 0
	// The name is escaped again in the message, as GNU does.
	assert res.output == '\\${escaped_name(odd)}: OK${eol}'
	os.rm(list)!
	os.rm(odd)!
}

// A name with anything worth quoting is quoted in an error message, so that it
// can be pasted into a shell.

fn test_quotes_name_in_error() {
	res := os.execute("${executable_under_test} 'no such file'")

	assert res.exit_code == 1
	assert res.output.trim_space() == "cksum: 'no such file': No such file or directory"
}
