// Every expectation here was measured against GNU 9.4's od on these bytes, and a
// differential run confirmed each one byte for byte. What is not covered: `-t f`
// (float), which GNU accepts and this does not, and stdin, whose binary mode the
// Windows build of this V does not provide.
module main

import common.testing
import os

const rig = testing.prepare_rig(util: 'od')

// 61 00 62 ff 63 0a: a printable byte, a NUL, a high byte, a printable and a
// newline, chosen so every format has something to say about every byte.
const sample_path = 'od_sample.bin'

// 40 copies of 0x41: more than one line, so the sixteen byte wrap and the `*`
// collapse are both exercised.
const repeats_path = 'od_repeats.bin'

// 17 copies of 0xff: a length that ends a line mid unit.
const odd_path = 'od_odd.bin'

// The rig moves the working directory to its own temporary folder before any test
// runs, so the fixtures are named relative to wherever that is.
fn testsuite_begin() {
	rig.assert_platform_util()
	// `os.write_file` takes text in this V, which would append a newline and turn a
	// NUL into a space. The bytes have to go in whole, so the file is built by hand.
	os.write_file(sample_path, bytes_of([0x61, 0x00, 0x62, 0xff, 0x63, 0x0a]))!
	os.write_file(repeats_path, bytes_of(repeated(0x41, 40)))!
	os.write_file(odd_path, bytes_of(repeated(0xff, 17)))!
}

// `os.write_file` in this V is the text form, so a byte list cannot go through it
// directly: a NUL would be written as a space and the file would gain a trailing
// newline, which is exactly the sort of corruption od exists to reveal.
fn bytes_of(values []int) string {
	mut s := []u8{cap: values.len}
	for v in values {
		s << u8(v)
	}
	return s.bytestr()
}

fn repeated(byte int, count int) []int {
	mut out := []int{cap: count}
	for _ in 0 .. count {
		out << byte
	}
	return out
}

fn testsuite_end() {
	os.rm(sample_path)!
	os.rm(repeats_path)!
	os.rm(odd_path)!
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

// GNU quotes the type string with U+2018 and U+2019, and prefixes its messages with
// its own argv[0]. The text is checked rather than left out, so a wrong reason still
// fails: only the program name and the quotes differ.
fn error_text_of(args string) string {
	res := os.execute('${rig.executable_under_test} ${args}')
	assert res.exit_code == 1
	return res.output.split_into_lines()[0]
}

// GNU accepts a bare `-b` but rejects `b` inside a `-t` string, so `-b` works and
// `-tb` does not. Measured.
fn test_b_works_on_its_own() {
	assert first_line('-b ${sample_path}') == '0000000 141 000 142 377 143 012'
}

fn test_b_rejects_inside_a_type_string() {
	assert error_text_of('-tb ${sample_path}').contains("invalid character 'b' in type string")
}

fn test_skip_past_the_end_fails() {
	assert error_text_of('-j 40 ${sample_path}') ==
		'od: cannot skip past end of combined input'
}

fn test_unknown_type_letter_fails() {
	assert error_text_of('-tq ${sample_path}').contains("invalid character 'q' in type string")
}

// One line is enough to pin a format's columns; the rest of the dump is covered by
// the cases that assert the whole output.
fn first_line(args string) string {
	return all_lines(args)[0]
}

fn all_lines(args string) []string {
	res := os.execute('${rig.executable_under_test} ${args}')
	// The failure has to say which invocation failed, because the assertion is in
	// here and not at the call site.
	assert res.exit_code == 0, 'od ${args}: exit ${res.exit_code}, output: ${res.output}'
	return res.output.split_into_lines()
}

fn test_default_is_two_byte_octal() {
	assert first_line(sample_path) == '0000000 000141 177542 005143'
}

fn test_hex_one_byte() {
	assert first_line('-tx1 ${sample_path}') == '0000000 61 00 62 ff 63 0a'
}

fn test_hex_two_bytes_is_little_endian() {
	assert first_line('-tx2 ${sample_path}') == '0000000 0061 ff62 0a63'
}

fn test_bare_x_is_a_machine_word() {
	assert first_line('-tx ${sample_path}') == '0000000 ff620061 00000a63'
}

fn test_octal_one_byte() {
	assert first_line('-to1 ${sample_path}') == '0000000 141 000 142 377 143 012'
}

fn test_char_names() {
	assert first_line('-tc ${sample_path}') == '0000000   a  \\0   b 377   c  \\n'
}

fn test_control_names() {
	assert first_line('-ta ${sample_path}') == '0000000   a nul   b del   c  nl'
}

fn test_two_character_formats_print_one_line_each() {
	assert all_lines('-tac ${sample_path}') == ['0000000   a nul   b del   c  nl',
		'          a  \\0   b 377   c  \\n', '0000006']
}

fn test_signed_decimal_is_a_machine_word() {
	assert first_line('-td ${sample_path}') == '0000000   -10354591        2659'
}

fn test_signed_decimal_two_bytes_is_positive() {
	// 0x0061 loads as 97 where the four byte load of the same bytes is negative:
	// the sign is the loaded word's own top bit, not the file's. Two bytes are set
	// in four columns, because a signed value is one wider than its digits: `-158`
	// fills its column and ` 97` is padded to match.
	assert first_line('-td2 ${sample_path}') == '0000000    97  -158  2659'
}

fn test_signed_decimal_one_byte_is_signed() {
	assert first_line('-td1 ${sample_path}') == '0000000    97     0    98    -1    99    10'
}

fn test_unsigned_decimal() {
	// Unsigned decimal is the same width as signed, so `2659` is padded like the
	// others rather than being left at its natural length.
	assert first_line('-tu2 ${sample_path}') == '0000000    97 65378  2659'
}

fn test_skip_and_limit() {
	assert all_lines('-tx1 -N2 -j1 ${sample_path}') == ['0000001 00 62', '0000003']
}

fn test_limit_alone() {
	assert all_lines('-N4 ${sample_path}') == ['0000000 000141 177542', '0000004']
}

fn test_skip_alone() {
	assert all_lines('-j2 ${sample_path}') == ['0000002 177542 005143', '0000006']
}

fn test_address_radix_decimal() {
	assert first_line('-Ad -tx1 -N8 ${repeats_path}') == '0000000 41 41 41 41 41 41 41 41'
}

fn test_address_radix_hex() {
	assert first_line('-Ax -tx1 -N8 ${repeats_path}') == '000000 41 41 41 41 41 41 41 41'
}

fn test_address_suppressed_keeps_the_leading_space() {
	// GNU prints the space the offset column would have taken, so the fields still
	// line up under the addressed form.
	assert all_lines('-An ${sample_path}') == [' 000141 177542 005143']
}

fn test_closing_offset_ends_the_dump() {
	lines := all_lines(sample_path)
	assert lines[lines.len - 1] == '0000006'
}

fn test_repeated_lines_collapse() {
	assert all_lines('-tx1 ${repeats_path}') ==
		['0000000 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41', '*',
			'0000040 41 41 41 41 41 41 41 41', '0000050']
}

fn test_verbose_prints_every_line() {
	lines := all_lines('-tx1 -v ${repeats_path}')
	assert !lines.join('\n').contains('*')
	assert lines.len == 4
}

fn test_seventeen_bytes_ends_mid_word() {
	// The last unit has one byte and its top bytes fell off the end, which are read
	// as zero: `000000ff` rather than `ffffffff`.
	assert all_lines('-tx ${odd_path}') ==
		['0000000 ffffffff ffffffff ffffffff ffffffff', '0000020 000000ff', '0000021']
}

fn test_two_character_formats_collapse_as_a_group() {
	// The `*` compares the whole group, so a repeat prints neither row: two rows,
	// then the star, then two rows, then the closing offset.
	lines := all_lines('-tac ${repeats_path}')
	assert lines == [
		'0000000   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A',
		'          A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A',
		'*',
		'0000040   A   A   A   A   A   A   A   A',
		'          A   A   A   A   A   A   A   A',
		'0000050',
	]
}
