module main

import os

const app_name = 'csplit'
const default_prefix = 'xx'
const default_digits = 2
// GNU quotes the operand in most of its complaints with these, not with `'`.
const quote_left = '\u2018'
const quote_right = '\u2019'

// PatKind is the five forms csplit --help lists for a PATTERN.
enum PatKind {
	// INTEGER: copy up to but not including that line number.
	line_number
	// /REGEXP/[OFFSET]: copy up to but not including a matching line.
	regex
	// %REGEXP%[OFFSET]: skip to, but not including, a matching line.
	skip
	// {INTEGER} and {*}: repeat the pattern before it.
	repeat
}

struct Pat {
mut:
	kind PatKind
	// text is the operand as the user wrote it, because the diagnostics quote the
	// operand rather than a normalised form of it.
	text string
	// number is the line number for .line_number, or the repeat count for
	// .repeat, where -1 stands for {*}.
	number int
	// re is the BRE source for .regex and .skip.
	re string
	// offset shifts the matched line, and is 0 when the operand carried none.
	offset int
}

// A Pat with its regular expression already built, so a pattern applied many times
// over does not rebuild it each time.
struct Compiled {
mut:
	pat Pat
	ere Ere
}

struct Settings {
mut:
	file        string
	patterns    []Pat
	prefix      string = default_prefix
	suffix      string
	digits      int = default_digits
	keep_files  bool
	suppress    bool
	silent      bool
	elide_empty bool
}

// LineIndex records where each line starts and ends, so a pattern can name a line
// number and a piece can be cut at one. Lines are counted from 1, and the trailing
// newline belongs to the line it ends.
struct LineIndex {
mut:
	starts []int
	// ends is one past the last byte of a line, newline included.
	ends []int
}

// LineIndex.build walks the data once. A last line without a newline is still a
// line and GNU writes it: over "1\n2\n3" a split at line 2 gives "1\n" and "2\n3",
// so three lines, not two.
fn LineIndex.build(data []u8) LineIndex {
	mut li := LineIndex{}
	mut at := 0
	for at < data.len {
		li.starts << at
		mut stop := at
		for stop < data.len && data[stop] != `\n` {
			stop++
		}
		if stop < data.len {
			stop++
		}
		li.ends << stop
		at = stop
	}
	return li
}

// subject is the line as a pattern sees it: the newline is not part of it, because
// GNU anchors $ to the end of the line. A CR is part of it, which is why "^2$" does
// not match the second line of a CRLF file.
fn (li LineIndex) subject(data []u8, line int) []u8 {
	mut stop := li.ends[line - 1]
	if stop > li.starts[line - 1] && data[stop - 1] == `\n` {
		stop--
	}
	return data[li.starts[line - 1]..stop]
}

fn (li LineIndex) count() int {
	return li.starts.len
}

// Cutter holds what one run of csplit needs, so the pattern loop does not have to
// thread five values through every call.
struct Cutter {
mut:
	settings Settings
	patterns []Compiled
	data     []u8
	lines    LineIndex
	// at is where the piece being built starts in data.
	at int
	// after is the line a pattern must match later than. It starts at 0, which is
	// why a first pattern may match the very first line, and it rises to the line
	// just cut at, which is why "/5/ /5/" finds no match the second time.
	after int
	// previous is the pattern a repetition repeats, kept because the repetition is a
	// separate operand that names nothing itself.
	previous Compiled
	// skipped records that the last successful pattern was a % skip, and pending_skip
	// that the pattern now failing is one. fail reads both; see its comment.
	skipped      bool
	pending_skip bool
	// quiet_failure suppresses the remainder for the one failure that reports nothing
	// at all, which is a line number against an empty input.
	quiet_failure bool
	index         int
	written       []string
}

fn main() {
	settings := parse_args() or { operand_error(err.msg()) }
	// The patterns are compiled before the input is opened, because GNU reads its
	// whole operand list before it touches the file: "/99/ [[:bogus:]]" over ten
	// lines complains about the class name and prints nothing, where a complaint
	// during the run would already have printed 21.
	patterns := compile_all(settings.patterns)
	data := read_input(settings.file) or {
		eprintln('${app_name}: ${err.msg()}')
		exit(1)
	}
	check_repetitions(settings.patterns)
	mut c := Cutter{
		settings: settings
		patterns: patterns
		data:     data
		lines:    LineIndex.build(data)
	}
	c.execute()
}

// compile_all builds every pattern's regular expression up front, and gives up on the
// first one that will not compile.
fn compile_all(pats []Pat) []Compiled {
	mut out := []Compiled{cap: pats.len}
	for p in pats {
		mut c := Compiled{
			pat: p
		}
		if p.kind == .regex || p.kind == .skip {
			c.ere.compile(p.re.bytes()) or {
				operand_error('${quoted(p.text)}: invalid regular expression: ${err.msg()}')
			}
		}
		out << c
	}
	return out
}

// execute walks the pattern list, writing a piece at every cut. It reports its own
// failures and leaves, because a failure has to remove the pieces already written
// unless -k was given, and a returned error cannot carry that decision.
fn (mut c Cutter) execute() {
	mut i := 0
	for i < c.patterns.len {
		cur := c.patterns[i]
		if cur.pat.kind == .repeat {
			c.repeat(c.previous, cur) or { c.fail(err.msg(), true) }
			i++
			continue
		}
		// A {*} is handled together with the pattern it repeats, because it decides
		// whether that pattern's own first failure matters, and because it ends the
		// list: "/3/ {*} /6/" over ten lines cuts only at line 3.
		if i + 1 < c.patterns.len && c.patterns[i + 1].pat.kind == .repeat
			&& c.patterns[i + 1].pat.number < 0 {
			if cur.pat.kind == .skip {
				// A % skip followed by {*} writes nothing at all and reports no size,
				// which is what "twenty lines, %1% {*}" does. Reproduced rather than
				// tidied, because matching GNU is the point of the port.
				return
			}
			c.star(cur) or { c.fail(err.msg(), false) }
			c.write_piece(c.at, c.data.len) or { c.fail(err.msg(), false) }
			return
		}
		c.apply(cur, 0) or { c.fail(err.msg(), false) }
		c.previous = cur
		i++
	}
	// Whatever is left after the last cut is the last piece.
	c.write_piece(c.at, c.data.len) or { c.fail(err.msg(), false) }
}

// star applies a pattern and keeps applying it for as long as it still matches. A
// {N} repetition is not the same thing and is handled by repeat.
//
// {*} absorbs the first failure of a pattern that searches, where {N} does not:
// over ten lines "/99/ {*}" succeeds and writes the file whole, while "/99/ {2}"
// fails. A line number gets no such softening, so "99 {*}" is still out of range.
//
// Nothing reads the position afterwards, because a {*} ends the pattern list, so
// there is no "where the repetition left off" to record here.
fn (mut c Cutter) star(p Compiled) ! {
	mut done := 0
	for {
		cut := c.find_cut(p, done) or {
			if p.pat.kind != .line_number {
				return
			}
			return err
		}
		c.cut_at(cut, false) or { return err }
		done++
	}
}

// repeat applies a pattern N more times after its first use. The first use has
// already happened in execute, so every failure here names a repetition number.
fn (mut c Cutter) repeat(previous Compiled, spec Compiled) ! {
	mut done := 0
	mut last := 0
	for done < spec.pat.number {
		cut := c.find_cut(previous, done + 1) or { return err }
		c.cut_at(cut, previous.pat.kind == .skip) or { return err }
		last = cut
		done++
	}
	// The line a repetition ends on is one before the line it last cut at, which is
	// measured: "3 {2} /9/" over ten lines finds line 9 again and writes an empty
	// piece, while "3 {1} /4/" finds nothing, because its last cut was line 6 and
	// line 4 is behind both 6 and 5.
	c.after = if last > 1 { last - 1 } else { 0 }
}

// apply uses one pattern once and writes the piece it ends. rep is the 1-based
// repetition number, or 0 when this is not a repetition; it only changes the wording
// of a failure.
fn (mut c Cutter) apply(p Compiled, rep int) ! {
	cut := c.find_cut(p, rep) or { return err }
	c.cut_at(cut, p.pat.kind == .skip) or { return err }
}

// find_cut reports which line a pattern cuts before. It is all of a pattern's
// behaviour; everything else in this file is bookkeeping around the answer.
fn (mut c Cutter) find_cut(p Compiled, rep int) !int {
	// fail reads this to tell a % pattern that failed from any other, and cut_at
	// reads the other one to tell a % pattern that succeeded.
	c.pending_skip = p.pat.kind == .skip
	mut complaint := ''
	if rep > 0 {
		complaint = ' on repetition ${rep}'
	}
	if p.pat.kind == .line_number {
		// A line number against an empty input is refused with a complaint of its
		// own, and GNU still leaves an empty first piece behind without reporting its
		// size. Measured on a zero-byte file: "csplit: input disappeared", one empty
		// xx00, nothing on stdout, exit 1.
		if c.lines.count() == 0 {
			c.write_empty_piece()
			c.quiet_failure = true
			return error('input disappeared')
		}
		// A line number is absolute the first time and steps by its own value on a
		// repetition: "3 {2}" over ten lines cuts at 3, 6 and 9, while "2" alone
		// cuts at 2.
		mut want := p.pat.number
		if rep > 0 {
			want = c.after + p.pat.number
		}
		if want > c.lines.count() {
			return error(quoted(p.pat.text) + ': line number out of range' + complaint)
		}
		return want
	}
	found := c.search(p) or {
		return error(quoted(p.pat.text) + ': match not found' + complaint)
	}
	return c.shift(found, p) or { return err }
}

// search finds the first line after the current position that the pattern matches.
// A pattern matching only the line it is already sitting on counts as no match,
// which is what makes "/5/ /5/" fail and what stops {*} for ever.
fn (mut c Cutter) search(p Compiled) ?int {
	mut line := c.after + 1
	for line <= c.lines.count() {
		if p.ere.matches(c.lines.subject(c.data, line)) {
			return line
		}
		line++
	}
	return none
}

// shift moves a match by the operand's OFFSET. An offset landing outside the file is
// a range complaint rather than a failed search: "/3/+99" over ten lines says "line
// number out of range", not "match not found".
fn (mut c Cutter) shift(found int, p Compiled) !int {
	if p.pat.offset == 0 {
		return found
	}
	mut want := found + p.pat.offset
	if want < 1 || want > c.lines.count() {
		return error(quoted(p.pat.text) + ': line number out of range')
	}
	return want
}

// cut_at writes the piece that ends at the given line and moves the position on.
//
// The piece always stops at the *start* of the cut line, so the matched line belongs
// to the piece that follows. --suppress-matched does not shorten the piece being
// written; it drops the matched line so that the next one starts after it, which is
// the difference measured over ten lines between "/5/" giving 8 and 13 bytes and
// "--suppress-matched /5/" giving 8 and 11.
//
// A .skip pattern writes nothing at all: it moves the start of the current piece up to
// its match and throws away what was before it. That is the whole difference between
// "/5/" and "%5%": over ten lines the first gives pieces of 8 and 13 bytes and the
// second a single piece of 13.
fn (mut c Cutter) cut_at(line int, skipping bool) ! {
	mut next := c.lines.starts[line - 1]
	if c.settings.suppress {
		next = c.lines.ends[line - 1]
	}
	if skipping {
		c.at = next
		c.after = line
		c.skipped = true
		return
	}
	c.write_piece(c.at, c.lines.starts[line - 1]) or { return err }
	// The position never goes backwards, so a cut naming a line that has gone by
	// leaves the piece where it already is.
	if next > c.at {
		c.at = next
	}
	c.after = line
	c.skipped = false
}

// fail writes out the piece that was in progress, prints the failure, removes the
// pieces already written unless -k was given, and leaves with GNU's exit code.
//
// The order is measured rather than tidied: "/99/" over ten lines prints 21 and then
// fails, and "/0/ /5/" prints 18 and 3 before failing, so the remainder is written and
// counted before the complaint is printed.
//
// Two measured cases write no remainder, and both are about a % skip. A pattern that
// failed while looking for its match writes nothing: "/3/ %99%" over ten lines prints
// only 4, where "%3% /99/" prints 17. And a repetition that failed straight after a
// skip writes nothing either: "%3% {1}" prints nothing at all, where "/3/ {1}" prints
// 4 and 17.
fn (mut c Cutter) fail(message string, from_repeat bool) {
	if !(c.quiet_failure || c.pending_skip || (c.skipped && from_repeat)) {
		c.write_piece(c.at, c.data.len) or {}
	}
	c.die(message)
}

fn (mut c Cutter) die(message string) {
	eprintln('${app_name}: ${message}')
	if !c.settings.keep_files {
		c.remove_written()
	}
	exit(1)
}

fn (mut c Cutter) remove_written() {
	for name in c.written {
		os.rm(name) or {}
	}
}

// write_piece writes one output file and prints its size, which is what csplit
// reports on stdout unless -s was given.
fn (mut c Cutter) write_piece(from int, to int) ! {
	// A cut can land behind the piece already built, which happens when a line
	// number names a line that has gone by: "3 {2} 7" over ten lines cuts at 9 and
	// then at 7, and GNU answers the second with an empty piece.
	mut end := to
	if end < from {
		end = from
	}
	if c.settings.elide_empty && end == from {
		return
	}
	name := c.piece_name() or { return err }
	mut f := os.create(name) or { return error('${name}: ${os.error_posix()}') }
	f.write(c.data[from..end]) or {
		f.close()
		return error('${name}: ${os.error_posix()}')
	}
	f.close()
	c.written << name
	if !c.settings.silent {
		println(end - from)
	}
	c.index++
}

// write_empty_piece creates the first output file with nothing in it and says nothing
// about its size. Only the empty-input case reaches it.
//
// It is deliberately not recorded as written, because the cleanup on a failure removes
// the pieces that were and GNU leaves this one behind even without -k: it never had a
// byte put in it.
fn (mut c Cutter) write_empty_piece() {
	name := c.piece_name() or { return }
	mut f := os.create(name) or { return }
	f.close()
}

// piece_name builds PREFIX followed by the piece number. A -b format replaces the
// default one and makes -n irrelevant, which is measured: "-b %02d -n 3" over ten
// lines still writes xx00 and xx01.
fn (c Cutter) piece_name() !string {
	return c.settings.prefix + suffix_digits(c.settings.suffix, c.settings.digits,
		c.index) or { return err }
}

// suffix_digits applies the -b format, or the "%0Nd" that -n asks for when -b was not
// given. Only one conversion is allowed and it has to be d, because that is all GNU
// accepts: "%s" and "%ld" are refused by name and "%d%d" is refused for having two.
fn suffix_digits(format string, digits int, index int) !string {
	if format == '' {
		return pad(index.str(), digits, true, false)
	}
	mut at := -1
	for i, b in format {
		if b == `%` {
			if at != -1 {
				return error('too many % conversion specifications in suffix')
			}
			at = i
		}
	}
	if at == -1 {
		return error('missing % conversion specification in suffix')
	}
	mut i := at + 1
	mut left := false
	mut zero := false
	for i < format.len && (format[i] == `-` || format[i] == `+` || format[i] == ` `
		|| format[i] == `#` || format[i] == `0`) {
		if format[i] == `-` {
			left = true
		}
		if format[i] == `0` {
			zero = true
		}
		i++
	}
	mut width := 0
	for i < format.len && format[i] >= `0` && format[i] <= `9` {
		width = width * 10 + int(format[i] - `0`)
		i++
	}
	mut precision := -1
	if i < format.len && format[i] == `.` {
		i++
		precision = 0
		for i < format.len && format[i] >= `0` && format[i] <= `9` {
			precision = precision * 10 + int(format[i] - `0`)
			i++
		}
	}
	if i >= format.len {
		return error('missing % conversion specification in suffix')
	}
	if format[i] != `d` {
		return error('invalid conversion specifier in suffix: ' +
			format[i].ascii_str())
	}
	// A precision on d is a minimum of digits rather than a column, so "%.2d" of 0 is
	// "00" and not " 0", and it zero-fills whatever the flags say.
	mut out := index.str()
	if precision >= 0 {
		out = pad(out, precision, true, false)
	}
	// The text either side of the conversion is kept, which is what makes
	// "-b out%d" name its pieces xxout0 and xxout1.
	return format[..at] + pad(out, width, zero, left) + format[i + 1..]
}

// pad applies printf's width rules to a non-negative number, which is the only thing
// a piece number ever is.
fn pad(digits string, want int, zero bool, left bool) string {
	if digits.len >= want {
		return digits
	}
	if left {
		return digits + ` `.str().repeat(want - digits.len)
	}
	if zero {
		return `0`.str().repeat(want - digits.len) + digits
	}
	return ` `.str().repeat(want - digits.len) + digits
}
