module main

// ere.v matches the pattern language GNU csplit hands to /REGEXP/ and %REGEXP%.
//
// That language is a GNU *basic* regular expression, not the POSIX extended one
// the manual's word "REGEXP" suggests. Every claim below was measured against
// csplit 9.4 with a one-line input, where a match shows up as an empty first
// output file:
//
//	^a+$     matches "a+"  but not "aa"     so + is an ordinary character
//	^a\?$    matches "a"                    so \? is the optional operator
//	^ab{1}$  matches "ab{1}"                so { is an ordinary character
//	^a|b$    matches "a|b"                  so | is an ordinary character
//	^\(a\)$  matches "a"                    so \( and \) are the grouping forms
//	^a^b$    matches "a^b"                  so ^ anchors only at the very start
//	^\101$   is refused as a back reference
//
// The zero-width \< \> \b \B and the shorthands \w \W \s \S are BRE features too,
// and are present, while \d \a \n \t are just the letters they look like.
//
// V's own `regex` module is not a substitute: its | binds to single tokens instead
// of to sequences, and it has neither POSIX character classes nor \b, so even a
// two-branch alternation cannot be expressed there at all.
//
// One deliberate difference: GNU matches a multibyte character as one character, so
// `.` covers `é` whole. This matcher works in bytes, so `.` covers one byte of it.
// That only shows up on input that is not ASCII.

const ere_unmatched_open = 'Unmatched ( or \\('
const ere_unmatched_close = 'Unmatched ) or \\)'
const ere_unmatched_brace = 'Unmatched \\{'
const ere_trailing_backslash = 'Trailing backslash'
const ere_bad_class_name = 'Invalid character class name'
const ere_bad_back_reference = 'Invalid back reference'
const ere_unmatched_bracket = 'Unmatched [ or [^'

enum EreKind {
	empty
	literal
	any
	class
	at_begin
	at_end
	word_begin
	word_end
	not_word_begin
	seq
	alt
	repeat
}

// EreSpan is one inclusive byte range of a bracket expression.
struct EreSpan {
	min u8
	max u8
}

// EreNode is one thing to match. Children are held by reference so that the tree is
// shared rather than copied as the matcher walks it. It is marked @[heap] because a
// reference to a node outlives the call that received it.
@[heap]
struct EreNode {
mut:
	kind    EreKind
	ch      u8
	negated bool
	spans   []EreSpan
	// A repeat body may match nothing, in which case there is no upper bound worth
	// trying and unbounded says so.
	min       int
	max       int
	unbounded bool
	kids      []&EreNode
}

// EreCont is one entry of the continuation a match works through: a node still to
// match, or a repetition that may still take another copy of its body. Carrying the
// repetition on the continuation is what lets it remember how many copies it has
// taken without the node itself being mutable.
enum EreContKind {
	node
	repeat
}

struct EreCont {
mut:
	kind  EreContKind
	ref   &EreNode
	count int
}

// Ere is a compiled pattern, ready to apply to many lines.
pub struct Ere {
mut:
	root EreNode
}

// compile parses a BRE pattern. The error carries GNU's own wording for the
// failure so that csplit can report it without restating it.
fn (mut e Ere) compile(pattern []u8) ! {
	mut p := EreParser{
		pattern: pattern
	}
	e.root = p.parse_alt() or { return err }
	// A parse that stopped early left a \) with nothing in front of it, which is the
	// one thing a branch cannot end on: "^\)" is refused rather than read as a ^.
	if p.pos < pattern.len {
		return error(ere_unmatched_close)
	}
}

// matches reports whether the pattern matches anywhere in the line. csplit only ever
// asks that question, never where the match fell, so no position comes back.
//
// Every offset in the line is a possible start, which is why "12" has to be found by
// a pattern of "2" starting one byte in.
fn (e &Ere) matches(line []u8) bool {
	for start in 0 .. line.len + 1 {
		if e.run([EreCont{
			ref: &e.root
		}], line, start) {
			return true
		}
	}
	return false
}

// run consumes the continuation until it runs out. An empty continuation means the
// whole pattern matched, and whatever is left of the line does not matter.
fn (e &Ere) run(next []EreCont, line []u8, at int) bool {
	if next.len == 0 {
		return true
	}
	c := next[0]
	rest := next[1..]
	if c.kind == .repeat {
		return e.repeat_from(c.ref, c.count, rest, line, at)
	}
	return e.step(c.ref, rest, line, at)
}

// repeat_from tries one more copy of the body before settling for the copies it
// already has, which is what makes * and + greedy. A count past the length of the
// line bounds the loop, which is what stops a body that matches the empty string from
// repeating for ever.
fn (e &Ere) repeat_from(n &EreNode, count int, rest []EreCont, line []u8, at int) bool {
	if (n.unbounded || count < n.max) && count <= line.len {
		mut cont := [
			EreCont{
				ref: n.kids[0]
			},
			EreCont{
				kind:  .repeat
				ref:   n
				count: count + 1
			},
		]
		cont << rest
		if e.run(cont, line, at) {
			return true
		}
	}
	if count >= n.min {
		return e.run(rest, line, at)
	}
	return false
}

// step matches one node.
fn (e &Ere) step(n &EreNode, next []EreCont, line []u8, at int) bool {
	match n.kind {
		.empty {
			return e.run(next, line, at)
		}
		.literal {
			if at < line.len && line[at] == n.ch {
				return e.run(next, line, at + 1)
			}
			return false
		}
		.any {
			if at < line.len {
				return e.run(next, line, at + 1)
			}
			return false
		}
		.class {
			if at < line.len && e.class_matches(n, line[at]) {
				return e.run(next, line, at + 1)
			}
			return false
		}
		.at_begin {
			return at == 0 && e.run(next, line, at)
		}
		.at_end {
			return at == line.len && e.run(next, line, at)
		}
		.word_begin {
			return at_word_begin(line, at) && e.run(next, line, at)
		}
		.word_end {
			return at_word_end(line, at) && e.run(next, line, at)
		}
		.not_word_begin {
			return !at_word_begin(line, at) && e.run(next, line, at)
		}
		.seq {
			mut cont := []EreCont{cap: n.kids.len + next.len}
			for kid in n.kids {
				cont << EreCont{
					ref: kid
				}
			}
			cont << next
			return e.run(cont, line, at)
		}
		.alt {
			for kid in n.kids {
				mut cont := [EreCont{
					ref: kid
				}]
				cont << next
				if e.run(cont, line, at) {
					return true
				}
			}
			return false
		}
		.repeat {
			mut cont := [
				EreCont{
					kind: .repeat
					ref:  n
				},
			]
			cont << next
			return e.run(cont, line, at)
		}
	}
}

// at_word_begin reports whether at sits where \< matches: after the start of the line
// or a non-word byte, and on a word byte.
fn at_word_begin(line []u8, at int) bool {
	if at >= line.len || !is_word_byte(line[at]) {
		return false
	}
	return at == 0 || !is_word_byte(line[at - 1])
}

// at_word_end reports whether at sits where \> matches: on a word byte followed by
// the end of the line or a non-word byte.
fn at_word_end(line []u8, at int) bool {
	if at >= line.len || !is_word_byte(line[at]) {
		return false
	}
	return at + 1 == line.len || !is_word_byte(line[at + 1])
}

// class_matches tests one byte against a bracket expression, honouring the negation
// a leading ^ puts on it.
fn (e &Ere) class_matches(n &EreNode, b u8) bool {
	mut hit := false
	for s in n.spans {
		if b >= s.min && b <= s.max {
			hit = true
			break
		}
	}
	return hit != n.negated
}

fn is_word_byte(b u8) bool {
	return (b >= `a` && b <= `z`) || (b >= `A` && b <= `Z`) || (b >= `0` && b <= `9`)
		|| b == `_`
}
