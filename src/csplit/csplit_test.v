import common.testing
import os

const rig = testing.prepare_rig(util: 'csplit')
const exe = rig.executable_under_test

// ten is ten lines of one, two and three digit numbers, 21 bytes: two for each of
// 1..9 and three for 10.
const input_name = 'in.txt'
const stdin_name = 'stdin.txt'
const ten = '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n'
// A file whose third line is "12", so a pattern of "2" and a line number of 2 have to
// be told apart: the text "2" is on line 3 and the second line is "b".
const ambiguous = 'a\nb\n12\nc\n'
// Nine lines of assorted text, 47 bytes, with two empty ones.
const words = 'alpha\n# comment\n\nbeta\ngamma\nEND\ndelta\n\nepsilon\n'

// Run is one invocation of the binary under test.
struct Run {
mut:
	code   int
	stdout string
	stderr string
	// names and contents hold the pieces in name order, which is the order csplit
	// creates them in.
	names    []string
	contents []string
}

// Case is one operand list and the complaint csplit is expected to make about it. A
// list of these rather than a map, because a map key cannot be an array.
struct Case {
	args      []string
	complaint string
}

// run drives the binary with an argument array and reads back what it wrote.
//
// os.execute is deprecated, goes through a shell, and cannot give a child any stdin at
// all; os.new_process takes the arguments as given and can read the child's stdin from
// a file, which is the only way an operand of "-" can be reached from a test.
fn run(args []string, stdin_path string) Run {
	mut p := os.new_process(exe)
	p.set_args(args)
	p.set_redirect_stdio()
	if stdin_path != '' {
		p.set_stdin_path(stdin_path)
	}
	p.wait()
	mut r := Run{
		code:   p.code
		stdout: p.stdout_slurp()
		stderr: p.stderr_slurp()
	}
	p.close()
	r.collect()
	return r
}

// run_in runs the tool over the input file, which is what nearly every case does, and
// saves each test from naming it.
fn run_in(args []string) Run {
	mut full := [input_name]
	full << args
	return run(full, '')
}

// collect reads the pieces out of the working directory, which prepare_rig has already
// moved into the tool's own temporary folder.
fn (mut r Run) collect() {
	mut names := (os.ls('.') or { [] }).filter(it != input_name && it != stdin_name).sorted()
	for n in names {
		r.names << n
		r.contents << os.read_file(n) or { '' }
	}
}

// sizes reads back just the byte counts csplit printed, which is the shape most of its
// behaviour is about.
fn (r Run) sizes() []string {
	return r.stdout.trim_space().split_into_lines().filter(it != '')
}

// expect is the assertion used everywhere: the exit code, the pieces and their names,
// their contents, and what csplit printed.
fn (r Run) expect(code int, names []string, contents []string, sizes []string) {
	assert r.code == code, 'exit ${r.code}, stderr [${r.stderr}]'
	assert r.names == names, 'names ${r.names}'
	assert r.contents == contents, 'contents ${r.contents}'
	assert r.sizes() == sizes, 'stdout [${r.stdout}]'
}

// expect_says checks only the complaint, for the cases where the pieces are not the
// point. The slurped streams keep the newline they were written with, so it is trimmed
// rather than spelled out in every expectation.
fn (r Run) expect_says(code int, complaint string) {
	assert r.code == code, 'exit ${r.code}, stderr [${r.stderr}]'
	assert r.stderr.trim_space() == complaint, 'said [${r.stderr}]'
}

// reset removes what a previous test left behind.
fn reset() {
	for f in os.ls('.') or { [] } {
		if f != input_name && f != stdin_name {
			os.rm(f) or {}
		}
	}
}

fn write_input(content string) {
	reset()
	os.write_file(input_name, content) or { panic(err) }
}

fn test_help_and_version() {
	rig.assert_help_and_version_options_work()
}

// A bare number is a line number, not the text it spells. Over a file whose third line
// is "12", "2" cuts before line 2 and "/2/" cuts before line 3.
fn test_bare_number_is_a_line_number_not_a_text_match() {
	write_input(ambiguous)
	run_in(['2']).expect(0, ['xx00', 'xx01'], ['a\n', 'b\n12\nc\n'], ['2', '7'])
	reset()
	run_in(['/2/']).expect(0, ['xx00', 'xx01'], ['a\nb\n', '12\nc\n'], ['4', '5'])
}

// The matched line belongs to the piece that follows, not the one that ends.
fn test_line_number_cuts_before_that_line() {
	write_input(ten)
	run_in(['3']).expect(0, ['xx00', 'xx01'], ['1\n2\n', '3\n4\n5\n6\n7\n8\n9\n10\n'], [
		'4',
		'17',
	])
}

fn test_two_patterns() {
	write_input(ten)
	run_in(['/3/', '/6/']).expect(0, ['xx00', 'xx01', 'xx02'], ['1\n2\n', '3\n4\n5\n', '6\n7\n8\n9\n10\n'], [
		'4',
		'6',
		'11',
	])
}

// --suppress-matched drops the matched line, so the piece after it starts one line
// further on.
fn test_suppress_matched_drops_the_line() {
	write_input(ten)
	run_in(['--suppress-matched', '/5/']).expect(0, ['xx00', 'xx01'],
		['1\n2\n3\n4\n', '6\n7\n8\n9\n10\n'], ['8', '11'])
	reset()
	run_in(['--suppress-matched', '5']).expect(0, ['xx00', 'xx01'],
		['1\n2\n3\n4\n', '6\n7\n8\n9\n10\n'], ['8', '11'])
	reset()
	run_in(['--suppress-matched', '%5%']).expect(0, ['xx00'], ['6\n7\n8\n9\n10\n'],
		['11'])
}

// A failure prints the piece it had reached before complaining, removes the pieces
// again, and leaves with 1. The order is checked because the obvious one, complaining
// first, would print nothing.
fn test_no_match_prints_the_remainder_then_fails() {
	write_input(ten)
	run_in(['/99/']).expect(1, []string{}, []string{}, ['21'])
	reset()
	run_in(['/99/', '-k']).expect(1, ['xx00'], [ten], ['21'])
	reset()
	run_in(['99']).expect(1, []string{}, []string{}, ['21'])
}

fn test_no_match_says_which_pattern() {
	write_input(ten)
	run_in(['/99/']).expect_says(1, 'csplit: ‘/99/’: match not found')
	reset()
	run_in(['99']).expect_says(1, 'csplit: ‘99’: line number out of range')
	reset()
	run_in(['99', '-k']).expect_says(1, 'csplit: ‘99’: line number out of range')
}

fn test_quiet_prints_no_sizes() {
	write_input(ten)
	run_in(['-s', '/5/']).expect(0, ['xx00', 'xx01'], ['1\n2\n3\n4\n', '5\n6\n7\n8\n9\n10\n'], []string{})
	reset()
	run_in(['--quiet', '/5/']).expect(0, ['xx00', 'xx01'], ['1\n2\n3\n4\n', '5\n6\n7\n8\n9\n10\n'], []string{})
}

// -f given twice takes the last. %REGEXP% throws away everything before its match
// rather than writing it.
fn test_prefix_takes_the_last_and_skip_discards() {
	write_input(ten)
	run_in(['-f', 'xx', '-f', 'yy', '/3/']).expect(0, ['yy00', 'yy01'], ['1\n2\n', '3\n4\n5\n6\n7\n8\n9\n10\n'], [
		'4',
		'17',
	])
	reset()
	run_in(['%5%']).expect(0, ['xx00'], ['5\n6\n7\n8\n9\n10\n'], ['13'])
	reset()
	run_in(['%5%', '/8/']).expect(0, ['xx00', 'xx01'], ['5\n6\n7\n', '8\n9\n10\n'],
		['6', '7'])
}

fn test_digits_and_suffix_format() {
	write_input(ten)
	run_in(['-n', '3', '/3/', '/6/']).expect(0, ['xx000', 'xx001', 'xx002'],
		['1\n2\n', '3\n4\n5\n', '6\n7\n8\n9\n10\n'], ['4', '6', '11'])
	reset()
	// A width of 0 pads to nothing at all.
	run_in(['-n', '0', '/3/']).expect(0, ['xx0', 'xx1'], ['1\n2\n', '3\n4\n5\n6\n7\n8\n9\n10\n'], [
		'4',
		'17',
	])
	reset()
	// -b keeps the prefix and puts the formatted number after it.
	run_in(['-b', 'out%d', '/3/']).expect(0, ['xxout0', 'xxout1'], ['1\n2\n', '3\n4\n5\n6\n7\n8\n9\n10\n'], [
		'4',
		'17',
	])
	reset()
	// -b wins over -n, which is measured rather than assumed.
	run_in(['-b', '%02d', '-n', '3', '/3/']).expect(0, ['xx00', 'xx01'], ['1\n2\n', '3\n4\n5\n6\n7\n8\n9\n10\n'], [
		'4',
		'17',
	])
}

fn test_suffix_format_complaints() {
	for format, complaint in {
		'nopct': 'csplit: missing % conversion specification in suffix'
		'x%s':   'csplit: invalid conversion specifier in suffix: s'
		'%ld':   'csplit: invalid conversion specifier in suffix: l'
		'%d%d':  'csplit: too many % conversion specifications in suffix'
	} {
		write_input(ten)
		run_in(['-b', format, '/3/']).expect_says(1, complaint)
	}
}

fn test_elide_empty_files() {
	write_input(ten)
	// The two patterns match lines 5 and 6, so without --suppress-matched nothing is
	// empty and -z changes nothing.
	run_in(['-z', '/5/', '/6/']).expect(0, ['xx00', 'xx01', 'xx02'],
		['1\n2\n3\n4\n', '5\n', '6\n7\n8\n9\n10\n'], ['8', '2', '11'])
	reset()
	// With it, the middle piece would be empty, and -z neither writes nor counts it.
	run_in(['-z', '--suppress-matched', '/5/', '/6/']).expect(0, ['xx00', 'xx01'],
		['1\n2\n3\n4\n', '7\n8\n9\n10\n'], ['8', '9'])
	reset()
	run_in(['--suppress-matched', '/5/', '/6/']).expect(0, ['xx00', 'xx01', 'xx02'],
		['1\n2\n3\n4\n', '', '7\n8\n9\n10\n'], ['8', '0', '9'])
}

// The offset after the closing delimiter moves the cut, and one that lands past the end
// of the file is a range complaint rather than a failed search.
fn test_offset_after_the_delimiter() {
	write_input(ten)
	run_in(['/3/+1']).expect(0, ['xx00', 'xx01'], ['1\n2\n3\n', '4\n5\n6\n7\n8\n9\n10\n'], [
		'6',
		'15',
	])
	reset()
	run_in(['/3/-1']).expect(0, ['xx00', 'xx01'], ['1\n', '2\n3\n4\n5\n6\n7\n8\n9\n10\n'], [
		'2',
		'19',
	])
	reset()
	run_in(['/3/+99']).expect_says(1, 'csplit: ‘/3/+99’: line number out of range')
}

// A line number repeated steps by its own value, which is why "3 {2}" cuts at 3, 6 and
// 9 rather than at 3 three times.
fn test_repeating_a_line_number() {
	write_input(ten)
	run_in(['3', '{2}']).expect(0, ['xx00', 'xx01', 'xx02', 'xx03'], ['1\n2\n', '3\n4\n5\n', '6\n7\n8\n',
		'9\n10\n'], ['4', '6', '6', '5'])
	reset()
	// {*} has no soft ending for a line number, so running off the end is a failure, and
	// it is reported as repetition 3 because the first two repeats did fit.
	run_in(['3', '{*}']).expect_says(1,
		'csplit: ‘3’: line number out of range on repetition 3')
	reset()
	run_in(['3', '{2}', '/9/']).expect(0, ['xx00', 'xx01', 'xx02', 'xx03', 'xx04'],
		['1\n2\n', '3\n4\n5\n', '6\n7\n8\n', '', '9\n10\n'], ['4', '6', '6', '0', '5'])
}

fn test_repeating_a_pattern_until_it_stops_matching() {
	write_input(ten)
	run_in(['/3/', '{*}']).expect(0, ['xx00', 'xx01'], ['1\n2\n', '3\n4\n5\n6\n7\n8\n9\n10\n'], [
		'4',
		'17',
	])
	reset()
	// {*} absorbs the first failure of a pattern that searches, where {2} does not.
	run_in(['/99/', '{*}']).expect(0, ['xx00'], [ten], ['21'])
	reset()
	run_in(['/99/', '{2}']).expect_says(1, 'csplit: ‘/99/’: match not found')
	reset()
	// {*} ends the pattern list: the /6/ after it never runs.
	run_in(['/3/', '{*}', '/6/']).expect(0, ['xx00', 'xx01'], ['1\n2\n', '3\n4\n5\n6\n7\n8\n9\n10\n'], [
		'4',
		'17',
	])
}

fn test_a_repetition_must_follow_a_plain_pattern() {
	for c in [
		Case{
			args:      ['{2}']
			complaint: 'csplit: ‘{2}’: invalid pattern'
		},
		Case{
			args:      ['{*}']
			complaint: 'csplit: ‘{*}’: invalid pattern'
		},
		Case{
			args:      ['/3/', '{2}', '{2}']
			complaint: 'csplit: ‘{2}’: invalid pattern'
		},
	] {
		write_input(ten)
		run_in(c.args).expect_says(1, c.complaint)
	}
}

fn test_bad_operands() {
	for c in [
		Case{
			args:      ['0']
			complaint: 'csplit: 0: line number must be greater than zero'
		},
		Case{
			args:      ['+0']
			complaint: 'csplit: +0: line number must be greater than zero'
		},
		Case{
			args:      ['zzz']
			complaint: 'csplit: ‘zzz’: invalid pattern'
		},
		Case{
			args:      ['%']
			complaint: "csplit: %: closing delimiter '%' missing"
		},
		Case{
			args:      ['/8%']
			complaint: "csplit: /8%: closing delimiter '/' missing"
		},
		Case{
			args:      ['/b/I']
			complaint: 'csplit: ‘/b/I’: integer expected after delimiter'
		},
	] {
		write_input(ten)
		run_in(c.args).expect_says(1, c.complaint)
	}
}

// A pattern is compiled while the operands are read, so a bad one is refused before
// anything is opened or written. The expected complaints double their backslashes,
// because csplit quotes the operand the way GNU does.
fn test_a_pattern_is_compiled_before_anything_is_written() {
	for c in [
		Case{
			args:      ['/[[:bogus:]]/']
			complaint: 'csplit: ‘/[[:bogus:]]/’: invalid regular expression: Invalid character class name'
		},
		Case{
			args:      ['/^\\)/']
			complaint: 'csplit: ‘/^\\\\)/’: invalid regular expression: Unmatched ) or \\)'
		},
		Case{
			args:      ['/^\\101$/']
			complaint: 'csplit: ‘/^\\\\101$/’: invalid regular expression: Invalid back reference'
		},
		Case{
			args:      ['/1\\{/']
			complaint: 'csplit: ‘/1\\\\{/’: invalid regular expression: Unmatched \\{'
		},
	] {
		write_input(ten)
		r := run_in(c.args)
		r.expect_says(1, c.complaint)
		assert r.stdout == '', '${c.args} printed [${r.stdout}]'
		assert r.names == []string{}, '${c.args} left ${r.names}'
	}
}

// The dialect is a basic regular expression, not the extended one the manual's word
// "REGEXP" suggests. Each expectation below is what GNU does with the same pattern over
// the same input, because the two dialects disagree about most of these.
fn test_the_pattern_language_is_a_basic_regular_expression() {
	write_input(words)
	// + is an ordinary character, so this wants a literal plus at the end. It matches
	// the fourth line, "beta", so the first piece is the three lines above it.
	run_in(['/^beta\\+$/']).expect(0, ['xx00', 'xx01'],
		['alpha\n# comment\n\n', 'beta\ngamma\nEND\ndelta\n\nepsilon\n'], ['17', '30'])
	reset()
	// So are the brackets, which is why this wants the text "(alpha)" and does not
	// find it. The closing \) with nothing to open it is refused outright.
	run_in(['/^(alpha)$/']).expect_says(1, 'csplit: ‘/^(alpha)$/’: match not found')
	reset()
	run_in(['/^(alpha\\|beta\\)$/']).expect_says(1,
		'csplit: ‘/^(alpha\\\\|beta\\\\)$/’: invalid regular expression: Unmatched ) or \\)')
	reset()
	// The escaped forms are the operators, and the bar splits the pattern whole, so a
	// ^ after it still anchors.
	run_in(['/^e\\|^a/']).expect(0, ['xx00', 'xx01'], ['', words], ['0', '47'])
	reset()
	// A counted interval needs the escaped braces, and both bounds take one. Each of
	// these matches the first line, so the first piece is empty.
	run_in(['/^[[:alpha:]]\\{5\\}$/']).expect(0, ['xx00', 'xx01'], ['',
		'alpha\n# comment\n\nbeta\ngamma\nEND\ndelta\n\nepsilon\n'], ['0', '47'])
	reset()
	run_in(['/^[[:alpha:]]\\{2,\\}$/']).expect(0, ['xx00', 'xx01'], ['',
		'alpha\n# comment\n\nbeta\ngamma\nEND\ndelta\n\nepsilon\n'], ['0', '47'])
	reset()
	// "beta" is the first line of exactly four letters, so the cut is after three.
	run_in(['/^[[:alpha:]]\\{2,4\\}$/']).expect(0, ['xx00', 'xx01'],
		['alpha\n# comment\n\n', 'beta\ngamma\nEND\ndelta\n\nepsilon\n'], ['17', '30'])
	reset()
	// ^ is an anchor at the front of a branch and the character anywhere else.
	run_in(['/a^b/']).expect_says(1, 'csplit: ‘/a^b/’: match not found')
}

fn test_posix_classes_and_word_boundaries() {
	write_input(words)
	// The space inside "# comment" is what this finds, at offset 1 of that line.
	run_in(['/[[:space:]]/']).expect(0, ['xx00', 'xx01'],
		['alpha\n', '# comment\n\nbeta\ngamma\nEND\ndelta\n\nepsilon\n'], ['6', '41'])
	reset()
	// \<eta\> needs a whole word, and neither "epsilon" nor "beta" gives it one.
	run_in(['/\\<eta\\>/']).expect_says(1, 'csplit: ‘/\\\\<eta\\\\>/’: match not found')
	reset()
	// \w and \s are classes, so this matches the first line; \d and \a are only the
	// letters they look like, so this wants a line holding nothing but a d.
	run_in(['/^\\w\\+$/']).expect(0, ['xx00', 'xx01'], ['',
		'alpha\n# comment\n\nbeta\ngamma\nEND\ndelta\n\nepsilon\n'], ['0', '47'])
	reset()
	run_in(['/^d$/']).expect_says(1, 'csplit: ‘/^d$/’: match not found')
	reset()
	run_in(['/^$/']).expect(0, ['xx00', 'xx01'], ['alpha\n# comment\n',
		'\nbeta\ngamma\nEND\ndelta\n\nepsilon\n'], ['16', '31'])
}

// A last line without a newline is still a line, and the pieces are cut on the exact
// bytes rather than on lines put back together with newlines.
fn test_input_without_a_trailing_newline() {
	write_input('1\n2\n3')
	run_in(['/2/']).expect(0, ['xx00', 'xx01'], ['1\n', '2\n3'], ['2', '3'])
	reset()
	run_in(['2']).expect(0, ['xx00', 'xx01'], ['1\n', '2\n3'], ['2', '3'])
}

fn test_empty_input() {
	write_input('')
	// A pattern that searches reports no match and prints nothing for the piece.
	run_in(['/2/']).expect_says(1, 'csplit: ‘/2/’: match not found')
	reset()
	// A line number has a complaint of its own, and still leaves an empty first piece
	// behind without reporting a size for it.
	r := run_in(['1'])
	r.expect_says(1, 'csplit: input disappeared')
	assert r.stdout == '', 'printed [${r.stdout}]'
	assert r.names == ['xx00'], '${r.names}'
	assert r.contents == [''], '${r.contents}'
}

fn test_input_that_cannot_be_opened() {
	reset()
	run(['no-such-file', '/3/'], '').expect_says(1,
		"csplit: cannot open 'no-such-file' for reading: No such file or directory")
}

// An operand of "-" reads standard input, which os.new_process can supply from a file.
fn test_reading_standard_input() {
	reset()
	os.write_file(stdin_name, ten) or { panic(err) }
	run(['-', '/3/'], stdin_name).expect(0, ['xx00', 'xx01'], ['1\n2\n', '3\n4\n5\n6\n7\n8\n9\n10\n'], [
		'4',
		'17',
	])
	reset()
	os.write_file(stdin_name, '1\n2\n3') or { panic(err) }
	run(['-', '/2/'], stdin_name).expect(0, ['xx00', 'xx01'], ['1\n', '2\n3'], ['2', '3'])
	reset()
	os.write_file(stdin_name, ten) or { panic(err) }
	run(['-', '/99/'], stdin_name).expect_says(1, 'csplit: ‘/99/’: match not found')
}

fn test_options_after_the_operands() {
	write_input(ten)
	run_in(['/5/', '-s']).expect(0, ['xx00', 'xx01'], ['1\n2\n3\n4\n', '5\n6\n7\n8\n9\n10\n'], []string{})
	reset()
	run_in(['--', '/3/']).expect(0, ['xx00', 'xx01'], ['1\n2\n', '3\n4\n5\n6\n7\n8\n9\n10\n'], [
		'4',
		'17',
	])
	reset()
	run_in(['-sz', '/5/']).expect(0, ['xx00', 'xx01'], ['1\n2\n3\n4\n', '5\n6\n7\n8\n9\n10\n'], []string{})
}

fn test_nothing_to_split_on() {
	write_input(ten)
	r := run([input_name], '')
	assert r.code == 1
	assert r.stderr.starts_with('csplit: missing operand after ‘in.txt’'), r.stderr
}
