module main

// File names appear in messages, where GNU quotes them so that a shell would take
// them literally. The rules below were taken from GNU cksum 9.4 itself, by
// checking one byte at a time as the first character of a name and as a later
// one, then fuzzing every one, two and three character name built from the
// characters worth quoting.
//
// One combination is still written differently: a name whose run of printable
// characters follows an escape and consists only of single quotes, such as a tab
// then '. GNU writes that run without reopening its quotes, and a difference of
// one quote character shows up. No name met in ordinary use takes that shape.

// Printable bytes GNU quotes wherever they appear.
const always_quoted = ' !"$&\'()*:;<=>?[\\^`|'

// Printable bytes GNU quotes only when they are the first character of a name,
// because a shell would expand them there.
const quoted_when_first = '~#'

const quote_char = u8(0x27)
const double_quote_char = u8(0x22)
const dollar_sign = u8(0x24)
const backtick_char = u8(0x60)

// Characters that stop GNU from choosing double quotes for a run that contains a
// single quote. A space and a colon do not, and neither does the single quote
// itself.
const blocks_double_quotes = '!"$&()*;<=>?[\\^`|{}'

// Characters that stop it too, but only away from the start of the name: GNU
// quotes a leading ~ or # because a shell would expand it, yet a ~ later in the
// name is harmless inside double quotes.
const blocks_double_quotes_when_not_first = '~#'

// quote_name renders a file name for a message. A name that needs no quoting is
// returned unchanged. Otherwise the name is split into runs: each run of printable
// characters is quoted, and each run of control characters and unprintable bytes
// is written as $'ooo', so that the result can be pasted into a shell.
fn quote_name(name string) string {
	if !needs_quoting(name) {
		return name
	}

	mut out := []u8{}
	mut run := []u8{}
	mut escapes := []u8{}
	mut escaped := false
	mut run_start := 0
	mut i := 0
	for i < name.len {
		c := name[i]
		width := utf8_width(c, name[i..])
		if width > 0 || !is_unprintable(c) {
			if escapes.len > 0 {
				append_escapes(mut out, escapes)
				escapes = []
				escaped = true
			}
			if run.len == 0 {
				run_start = i
			}
			for k in i .. i + if width > 0 { width } else { 1 } {
				run << name[k]
			}
			i += if width > 0 { width } else { 1 }
			continue
		}
		// An empty run before a group of escapes is written as '', which is how a
		// name that is a single control character comes out as ''$'\001'.
		if escapes.len == 0 {
			append_quoted_run(mut out, run.bytestr(), run_start == 0, escaped)
			run = []
		}
		escapes << c
		i++
	}
	if escapes.len > 0 {
		append_escapes(mut out, escapes)
		escaped = true
	}
	if run.len > 0 {
		append_quoted_run(mut out, run.bytestr(), run_start == 0, escaped)
	}
	if out.len == 0 {
		// The name was empty.
		append_quoted_run(mut out, '', true, false)
	}
	return out.bytestr()
}

// needs_quoting reports whether GNU would quote this name at all.
fn needs_quoting(name string) bool {
	if name.len == 0 {
		return true
	}
	// A brace on its own is quoted, while a brace inside a name is not: GNU
	// writes '{}' but leaves '{a' and '{}' alone.
	if name == '{' || name == '}' {
		return true
	}
	mut i := 0
	for i < name.len {
		c := name[i]
		width := utf8_width(c, name[i..])
		if width > 1 {
			i += width
			continue
		}
		if is_unprintable(c) || contains_byte(always_quoted, c) {
			return true
		}
		if i == 0 && contains_byte(quoted_when_first, c) {
			return true
		}
		i++
	}
	return false
}

// append_quoted_run writes one run of printable characters. GNU uses double quotes
// when a single quote is the only character in the run that needs quoting, and
// otherwise ends the run, writes an escaped quote, and starts a new one. It also
// drops back to single quotes once an escape has been written, and treats ~ and #
// as harmless only at the start of the name.
fn append_quoted_run(mut out []u8, run string, at_name_start bool, escaped bool) {
	if run.len == 0 {
		out << quote_char
		out << quote_char
		return
	}
	if only_quote_is_single(run, at_name_start, escaped) {
		out << double_quote_char
		append_all(mut out, run)
		out << double_quote_char
		return
	}
	out << quote_char
	for c in run {
		if c == quote_char {
			out << quote_char
			out << backslash[0]
			out << quote_char
			out << quote_char
		} else {
			out << c
		}
	}
	out << quote_char
}

// append_escapes writes a run of control characters and unprintable bytes as one
// $'...'.
fn append_escapes(mut out []u8, escapes []u8) {
	out << dollar_sign
	out << quote_char
	for c in escapes {
		append_all(mut out, control_escape(c))
	}
	out << quote_char
}

// only_quote_is_single reports whether a single quote is the only character in the
// run that GNU has to quote, which is when it wraps the run in double quotes.
fn only_quote_is_single(run string, at_name_start bool, escaped bool) bool {
	mut found := false
	for i, c in run {
		if c == quote_char {
			found = true
		} else if contains_byte(blocks_double_quotes, c) {
			return false
		} else if contains_byte(blocks_double_quotes_when_not_first, c)
			&& !(at_name_start && i == 0) {
			return false
		}
	}
	return found && !escaped
}

// control_escape is the C escape GNU writes inside $'...'. The common ones have a
// name; everything else is written as three octal digits.
fn control_escape(c u8) string {
	named := match c {
		7 { '\\a' }
		8 { '\\b' }
		9 { '\\t' }
		10 { '\\n' }
		11 { '\\v' }
		12 { '\\f' }
		13 { '\\r' }
		else { '' }
	}
	if named.len > 0 {
		return named
	}
	mut out := []u8{}
	out << backslash[0]
	out << u8(0x30 + ((c >> 6) & 7))
	out << u8(0x30 + ((c >> 3) & 7))
	out << u8(0x30 + (c & 7))
	return out.bytestr()
}

// is_unprintable reports whether a byte cannot appear literally in a message.
fn is_unprintable(c u8) bool {
	return c < 0x20 || c == 0x7f || c >= 0x80
}

// utf8_width returns how many bytes the UTF-8 sequence starting at c occupies,
// or 0 when the bytes there are not a valid sequence. GNU prints a valid sequence
// as it stands and escapes an invalid one byte by byte.
fn utf8_width(c u8, rest string) int {
	if c < 0x80 {
		return 0
	}
	mut width := 0
	mut low := 0x80
	mut high := 0xbf
	if c >= 0xc2 && c <= 0xdf {
		width = 2
	} else if c == 0xe0 {
		width = 3
		low = 0xa0
	} else if c >= 0xe1 && c <= 0xec {
		width = 3
	} else if c == 0xed {
		width = 3
		high = 0x9f
	} else if c >= 0xee && c <= 0xef {
		width = 3
	} else if c == 0xf0 {
		width = 4
		low = 0x90
	} else if c >= 0xf1 && c <= 0xf3 {
		width = 4
	} else if c == 0xf4 {
		width = 4
		high = 0x8f
	} else {
		return 0
	}
	if rest.len < width {
		return 0
	}
	if rest[1] < low || rest[1] > high {
		return 0
	}
	for k in 2 .. width {
		if rest[k] < 0x80 || rest[k] > 0xbf {
			return 0
		}
	}
	return width
}

// append_all copies a string's bytes into a byte buffer.
fn append_all(mut out []u8, s string) {
	for c in s {
		out << c
	}
}

fn contains_byte(set string, c u8) bool {
	for x in set {
		if x == c {
			return true
		}
	}
	return false
}
