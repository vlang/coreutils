import common.testing
import os

const rig = testing.prepare_rig(util: 'join')
const exe = rig.executable_under_test

// The two files every case joins.
//
// The join field is the first one, so the three a lines on the left each pair with the
// single a line on the right, and b, c and d are left over:
//
//	f1.txt: a 1 x 5 p    f2.txt: a 3 z 7 r
//	        a 1 x 6 q            c 4 w
//	        a 2 y 5 p            d 8 s
//	        b 3 z 7 r
const left_name = 'f1.txt'
const right_name = 'f2.txt'
// b's join field is b and nothing on the right carries it, so b is an unpaired line of
// file 1; c and d are unpaired lines of file 2. Every expectation below turns on that
// split, so it is spelled out rather than left to be rediscovered.
const left = 'a 1 x 5 p\na 1 x 6 q\na 2 y 5 p\nb 3 z 7 r\n'
const right = 'a 3 z 7 r\nc 4 w\nd 8 s\n'

// Run is one invocation of the binary under test.
struct Run {
mut:
	code   int
	stdout string
	stderr string
}

// run drives the binary with an argument array and reads back what it wrote.
//
// os.execute is deprecated, goes through a shell, and cannot give a child any stdin at
// all, so it cannot be used for a case whose argument contains a space or a quote.
fn run(args []string) Run {
	mut p := os.new_process(exe)
	p.set_args(args)
	p.set_redirect_stdio()
	p.wait()
	mut r := Run{
		code:   p.code
		stdout: p.stdout_slurp()
		stderr: p.stderr_slurp()
	}
	p.close()
	return r
}

// both runs the tool over the two input files, which is what nearly every case does, and
// saves each test from naming them.
fn both(args []string) Run {
	mut full := [left_name]
	full << args
	full << right_name
	return run(full)
}

// pairs is the three matched lines under the default shape. It is what every case that
// only adds an option on top of the default output starts from.
const pairs = 'a 1 x 5 p 3 z 7 r\na 1 x 6 q 3 z 7 r\na 2 y 5 p 3 z 7 r\n'

// reset rewrites the two input files, so a case starts from a known pair whatever the
// previous one did to the directory.
fn reset() {
	os.write_file(left_name, left) or { panic(err) }
	os.write_file(right_name, right) or { panic(err) }
}

// expect is the assertion used everywhere: the exit code, what went to stdout, and that
// nothing went to stderr.
fn (r Run) expect(code int, stdout string) {
	assert r.code == code, 'exit ${r.code}, stderr [${r.stderr}]'
	assert r.stdout == stdout, 'stdout [${r.stdout}]'
	assert r.stderr == '', 'stderr [${r.stderr}]'
}

// expect_says checks only the complaint, for the cases where the output is not the
// point. The slurped stream keeps the newline it was written with, so it is trimmed
// rather than spelled out in every expectation.
fn (r Run) expect_says(code int, complaint string) {
	assert r.code == code, 'exit ${r.code}, stderr [${r.stderr}]'
	assert r.stderr.trim_space() == complaint, 'said [${r.stderr}]'
}

fn test_default_shape_prints_only_the_pairs() {
	reset()
	// The join field is printed once, then the rest of the left line, then the rest of the
	// right line. b is unpaired, so nothing is printed for it unless -a or -v asks.
	both([]).expect(0, pairs)
}

fn test_missing_join_field_pairs_everything() {
	reset()
	// -j 9 asks for a ninth field, which neither file has, so every line on the left pairs
	// with every line on the right on the empty value of that field. The join field prints
	// as empty, which leaves the leading blank, and the whole line is each remainder.
	both(['-j', '9']).expect(0, ' a 1 x 5 p a 3 z 7 r\n a 1 x 5 p c 4 w\n a 1 x 5 p d 8 s\n' +
		' a 1 x 6 q a 3 z 7 r\n a 1 x 6 q c 4 w\n a 1 x 6 q d 8 s\n' +
		' a 2 y 5 p a 3 z 7 r\n a 2 y 5 p c 4 w\n a 2 y 5 p d 8 s\n' +
		' b 3 z 7 r a 3 z 7 r\n b 3 z 7 r c 4 w\n b 3 z 7 r d 8 s\n')
}

fn test_one_field_each_leaves_nothing_after_the_join_field() {
	reset()
	// A single field per line means the join field is the whole line and there is no
	// remainder, so the matched lines print as just their key.
	os.write_file(left_name, 'a\na\nb\n') or { panic(err) }
	os.write_file(right_name, 'a\nc\n') or { panic(err) }
	both([]).expect(0, 'a\na\n')
}

fn test_o_lists_the_fields_it_wants() {
	reset()
	// -o 0 asks for the join field alone, once per pair.
	both(['-o', '0']).expect(0, 'a\na\na\n')
	reset()
	// Field 1.2, then 1.3, then 2.2: the second and third fields of the left line and the
	// second field of the right one.
	both(['-o', '1.2,1.3,2.2']).expect(0, '1 x 3\n1 x 3\n2 y 3\n')
}

fn test_t_reshapes_every_field_not_just_the_join_field() {
	reset()
	// -t replaces the separator of the whole line, so with a colon in it no line has more
	// than one field. The join field is then the entire line, nothing matches, and the
	// output is empty rather than an error.
	both(['-t', ':']).expect(0, '')
	reset()
	// With a tab the lines split as before, so the same three pairs come back - and the
	// tab is the separator of the output too, not only of the input.
	os.write_file(left_name, 'a\t1 x 5 p\na\t2 y 5 p\n') or { panic(err) }
	os.write_file(right_name, 'a\t3 z 7 r\n') or { panic(err) }
	both(['-t', '\t']).expect(0, 'a\t1 x 5 p\t3 z 7 r\na\t2 y 5 p\t3 z 7 r\n')
	reset()
	os.write_file(left_name, 'a,1 x 5 p\n') or { panic(err) }
	os.write_file(right_name, 'a,3 z 7 r\n') or { panic(err) }
	both(['-t', ',']).expect(0, 'a,1 x 5 p,3 z 7 r\n')
}

fn test_e_has_no_missing_field_to_fill_in_these_files() {
	reset()
	// Every matched line here carries both 1.2 and 2.2, so -e never fires and the output is
	// the same as without it. This pins that -e does not disturb the ordinary shape; it is
	// not a test of the substitution itself.
	both(['-e', 'EMPTY', '-o', '1.2,2.2']).expect(0, '1 3\n1 3\n2 3\n')
}

fn test_a_prints_the_unpaired_lines_of_the_named_file() {
	reset()
	// b is file 1's only unpaired line, and an unpaired line is printed as it stands,
	// without the -o shape that a pair gets.
	both(['-a1']).expect(0, pairs + 'b 3 z 7 r\n')
	reset()
	both(['-a2']).expect(0, pairs + 'c 4 w\nd 8 s\n')
	reset()
	// Every occurrence counts, so -a1 -a2 is the same as -a2 and -a1 together.
	both(['-a1', '-a2']).expect(0, pairs + 'b 3 z 7 r\nc 4 w\nd 8 s\n')
	reset()
	// The glued spelling has to reach the same place.
	both(['-a2']).expect(0, pairs + 'c 4 w\nd 8 s\n')
	reset()
	// -o shapes the unpaired lines as well as the pairs, so the three pairs contribute
	// their second field and b contributes its own.
	both(['-a1', '-o', '1.2']).expect(0, '1\n1\n2\n3\n')
	reset()
	both(['-a2', '-o', '2.2']).expect(0, '3\n3\n3\n4\n8\n')
}

fn test_v_drops_the_pairs_and_keeps_only_the_named_file() {
	reset()
	both(['-v1']).expect(0, 'b 3 z 7 r\n')
	reset()
	both(['-v2']).expect(0, 'c 4 w\nd 8 s\n')
	reset()
	both(['-v1', '-v2']).expect(0, 'b 3 z 7 r\nc 4 w\nd 8 s\n')
	reset()
	// -o shapes the unpaired lines too, so b contributes its second field and nothing else.
	both(['-v1', '-o', '1.2']).expect(0, '3\n')
}

fn test_i_ignores_case_in_the_join_field() {
	reset()
	os.write_file(left_name, 'A 1 x\n') or { panic(err) }
	os.write_file(right_name, 'a 2 y\n') or { panic(err) }
	both([]).expect(0, '')
	both(['-i']).expect(0, 'A 1 x 2 y\n')
}

fn test_a_complaint_names_the_field_or_the_file() {
	reset()
	// -o 1 names a file but no field, which is a different complaint from -o 3, where 3
	// is not one of the two files at all.
	both(['-o', '1']).expect_says(1, 'join: invalid field specifier: ‘1’')
	reset()
	both(['-o', '3']).expect_says(1, 'join: invalid file number in field spec: ‘3’')
	reset()
	// An empty -o is refused rather than read as the default shape.
	both(['-o', '']).expect_says(1, 'join: invalid file number in field spec: ‘’')
	reset()
	// e belongs to -e, not to -o.
	both(['-o', 'e']).expect_says(1, 'join: invalid file number in field spec: ‘e’')
	reset()
	both(['-o', '1.x']).expect_says(1, 'join: invalid field number: ‘x’')
	reset()
	// The file number of -a is a field number too, and 3 is not one of the two files.
	both(['-a', '3']).expect_says(1, 'join: invalid field number: ‘3’')
	reset()
	// -t takes one character, so a longer one is refused.
	both(['-t', 'ab']).expect_says(1, 'join: multi-character tab ‘ab’')
}

fn test_a_missing_file_is_reported_without_the_error_code() {
	reset()
	// The complaint carries the name of the file that is missing, and none of the
	// "; code: N" tail that os.error_posix reports, because GNU does not print one.
	run([left_name, 'nope.txt']).expect_says(1, 'join: nope.txt: No such file or directory')
}
