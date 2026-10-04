module main

// ere_parser.v turns BRE source into the node tree that ere.v matches against. The
// grammar it accepts is the one measured in ere.v's header:
//
//	alt        := concat ('\|' concat)*
//	concat     := piece*
//	piece      := atom quantifier*
//	quantifier := '*' | '\+' | '\?' | '\{' n [',' [m]] '\}'
//	atom       := '\(' alt '\)' | bracket | '.' | '^' | '$' | '\' escape | character
//
// Two rules are easy to get wrong and are both measured rather than assumed. A * with
// nothing in front of it to repeat is an ordinary character, which is what makes a *
// at the start of a pattern, or straight after \( or \|, a literal. And ^ and $ are
// anchors only at the very start or very end of the whole pattern, so ^a^b$ matches
// the text a^b.

struct EreParser {
mut:
	pattern []u8
	pos     int
	// at_start is true where a * would have nothing to repeat: through the first
	// piece of a pattern, and straight after every \( and \|.
	at_start bool = true
	// repeatable is true where something a repetition could attach to has just been
	// read. An anchor is not one, which is why ^\{ is a brace and not an interval.
	repeatable bool
}

struct EreInterval {
mut:
	min int
	max int
}

fn ere_span(lo u8, hi u8) EreSpan {
	return EreSpan{
		min: lo
		max: hi
	}
}

fn ere_literal(b u8) &EreNode {
	return &EreNode{
		kind: .literal
		ch:   b
	}
}

fn ere_marker(kind EreKind) &EreNode {
	return &EreNode{
		kind: kind
	}
}

// posix_spans returns the byte ranges of a [:name:] class, or none when the name is
// not one. GNU refuses an unknown name rather than taking it literally, which is what
// the caller turns into an error.
fn posix_spans(name string) ?[]EreSpan {
	return match name {
		'alnum' {
			[ere_span(`0`, `9`), ere_span(`A`, `Z`), ere_span(`a`, `z`)]
		}
		'alpha' {
			[ere_span(`A`, `Z`), ere_span(`a`, `z`)]
		}
		'blank' {
			[ere_span(`\t`, `\t`), ere_span(` `, ` `)]
		}
		'cntrl' {
			[ere_span(0, 31), ere_span(127, 127)]
		}
		'digit' {
			[ere_span(`0`, `9`)]
		}
		'graph' {
			[ere_span(33, 126)]
		}
		'lower' {
			[ere_span(`a`, `z`)]
		}
		'print' {
			[ere_span(32, 126)]
		}
		'punct' {
			[
				ere_span(`!`, `/`),
				ere_span(`:`, `@`),
				ere_span(`[`, u8(96)),
				ere_span(`{`, `~`),
			]
		}
		'space' {
			[ere_span(9, 13), ere_span(` `, ` `)]
		}
		'upper' {
			[ere_span(`A`, `Z`)]
		}
		'xdigit' {
			[ere_span(`0`, `9`), ere_span(`A`, `F`), ere_span(`a`, `f`)]
		}
		else {
			none
		}
	}
}

fn (p EreParser) at_end() bool {
	return p.pos >= p.pattern.len
}

fn (p EreParser) peek_is(want u8) bool {
	return !p.at_end() && p.pattern[p.pos] == want
}

fn (p EreParser) next_is(want u8) bool {
	return p.pos + 1 < p.pattern.len && p.pattern[p.pos + 1] == want
}

fn (mut p EreParser) take() u8 {
	b := p.pattern[p.pos]
	p.pos++
	return b
}

fn (p EreParser) byte_at(i int) u8 {
	return if i < p.pattern.len { p.pattern[i] } else { 0 }
}

// at_alt_bar reports whether the parser is sitting on the \| that joins two branches.
// The unescaped | is an ordinary character in a BRE, so only this spelling counts.
fn (p EreParser) at_alt_bar() bool {
	return p.peek_is(`\\`) && p.next_is(`|`)
}

// at_close_group reports whether the parser is on the \) that ends the group it is
// inside, which parse_concat has to stop for so that the group can close.
fn (p EreParser) at_close_group() bool {
	return p.peek_is(`\\`) && p.next_is(`)`)
}

// parse_alt reads a concatenation, or several joined by \|.
fn (mut p EreParser) parse_alt() !&EreNode {
	mut branches := [p.parse_concat() or { return err }]
	for p.at_alt_bar() {
		p.pos += 2
		p.at_start = true
		p.repeatable = false
		branches << p.parse_concat() or { return err }
	}
	if branches.len == 1 {
		return branches[0]
	}
	return &EreNode{
		kind: .alt
		kids: branches
	}
}

// parse_concat reads a run of pieces, stopping before whatever belongs to an
// enclosing group or alternation rather than to this branch.
fn (mut p EreParser) parse_concat() !&EreNode {
	mut kids := []&EreNode{}
	for !(p.at_end() || p.at_alt_bar() || p.at_close_group()) {
		kids << p.parse_piece() or { return err }
	}
	return &EreNode{
		kind: .seq
		kids: kids
	}
}

// parse_piece reads one atom with any quantifiers applied to it.
fn (mut p EreParser) parse_piece() !&EreNode {
	mut n := p.parse_atom() or { return err }
	for !p.at_end() {
		q := p.parse_quantifier(n) or { return err }
		if q.kind == .empty {
			break
		}
		n = q
	}
	return n
}

// parse_quantifier reads one repetition suffix applied to body, or reports an .empty
// node when the parser is not sitting on one, which is how parse_piece knows to stop.
fn (mut p EreParser) parse_quantifier(body &EreNode) !&EreNode {
	mut lo := 0
	mut hi := 0
	if p.peek_is(`*`) {
		// A literal when there is nothing in front of it to repeat.
		if p.at_start {
			return ere_marker(.empty)
		}
		p.pos++
		lo = 0
		hi = -1
	} else if p.peek_is(`\\`) && p.pos + 1 < p.pattern.len {
		match p.pattern[p.pos + 1] {
			`+` {
				p.pos += 2
				lo = 1
				hi = -1
			}
			`?` {
				p.pos += 2
				lo = 0
				hi = 1
			}
			`{` {
				// A \{ opens an interval only when something a repetition could attach
				// to came before it. Measured: /a\{b/ and /1\{2/ are refused as an
				// unmatched \{, while /\{/ and /^\{/ are the character itself.
				if !p.repeatable {
					return ere_marker(.empty)
				}
				iv := p.parse_interval() or { return err }
				lo = iv.min
				hi = iv.max
			}
			else {
				return ere_marker(.empty)
			}
		}
	} else {
		return ere_marker(.empty)
	}
	p.at_start = false
	p.repeatable = true
	return &EreNode{
		kind:      .repeat
		kids:      [body]
		min:       lo
		max:       hi
		unbounded: hi < 0
	}
}

// parse_interval reads the body of a \{n\}, \{n,\} or \{n,m\} repetition. A { that does
// not open a well-formed interval is an ordinary character, which is measured rather
// than assumed: ^\{$ matches a line reading {, and \{2 matches nothing at all.
fn (mut p EreParser) parse_interval() !EreInterval {
	mut i := p.pos + 2
	mut lo := 0
	mut digits := 0
	for p.byte_at(i) >= `0` && p.byte_at(i) <= `9` && i < p.pattern.len {
		lo = lo * 10 + int(p.byte_at(i) - `0`)
		digits++
		i++
	}
	if digits == 0 {
		return error(ere_unmatched_brace)
	}
	mut hi := lo
	if p.byte_at(i) == `,` {
		i++
		// \{n,} leaves the count open above, and the closing brace may be escaped.
		if p.at_interval_end(i) {
			hi = -1
			p.pos = i + if p.byte_at(i) == `}` { 1 } else { 2 }
			return EreInterval{
				min: lo
				max: hi
			}
		}
		hi = 0
		digits = 0
		for p.byte_at(i) >= `0` && p.byte_at(i) <= `9` && i < p.pattern.len {
			hi = hi * 10 + int(p.byte_at(i) - `0`)
			digits++
			i++
		}
		if digits == 0 || !p.at_interval_end(i) {
			return error(ere_unmatched_brace)
		}
		p.pos = i + if p.byte_at(i) == `}` { 1 } else { 2 }
		return EreInterval{
			min: lo
			max: hi
		}
	}
	if !p.at_interval_end(i) {
		return error(ere_unmatched_brace)
	}
	// An unescaped closing brace ends the interval too, so a\{2\} and a\{2} mean
	// the same thing.
	p.pos = i + if p.byte_at(i) == `}` { 1 } else { 2 }
	return EreInterval{
		min: lo
		max: hi
	}
}

fn (p EreParser) at_interval_end(i int) bool {
	return p.byte_at(i) == `}` || (p.byte_at(i) == `\\` && p.byte_at(i + 1) == `}`)
}

// parse_atom reads one thing to match.
fn (mut p EreParser) parse_atom() !&EreNode {
	if p.at_end() {
		return error(ere_unmatched_open)
	}
	b := p.pattern[p.pos]
	match b {
		`\\` {
			return p.parse_escape()
		}
		`[` {
			return p.parse_bracket()
		}
		`.` {
			p.pos++
			p.at_start = false
			p.repeatable = true
			return ere_marker(.any)
		}
		`^` {
			// An anchor at the front of a branch, which is the front of the whole
			// pattern and also the front of every piece after a \|. Measured two ways:
			// "^a^b$" matches the text a^b, so a ^ anywhere else is the character, and
			// "^e\|^a" matches "alpha", so the ^ after the bar still anchors.
			mut anchor := p.at_start
			p.pos++
			p.at_start = false
			p.repeatable = false
			if anchor {
				return ere_marker(.at_begin)
			}
			return ere_literal(b)
		}
		`$` {
			mut anchor := p.pos == p.pattern.len - 1
			p.pos++
			p.at_start = false
			p.repeatable = false
			if anchor {
				return ere_marker(.at_end)
			}
			return ere_literal(b)
		}
		else {
			// ( and ) are ordinary characters in a BRE: ^(a)$ matches the text (a)
			// and not a.
			p.pos++
			p.at_start = false
			p.repeatable = true
			return ere_literal(b)
		}
	}
}

// parse_escape reads a backslash and whatever follows it. The operators are a short
// list; a backslash in front of anything else is dropped and the character stands for
// itself, which is why \d matches a d and \a matches an a.
fn (mut p EreParser) parse_escape() !&EreNode {
	p.pos++ // the backslash
	if p.at_end() {
		return error(ere_trailing_backslash)
	}
	b := p.take()
	match b {
		`(` {
			return p.parse_group()
		}
		`)` {
			return error(ere_unmatched_close)
		}
		`<`, `b` {
			p.at_start = false
			p.repeatable = false
			return ere_marker(.word_begin)
		}
		`>` {
			p.at_start = false
			p.repeatable = false
			return ere_marker(.word_end)
		}
		`B` {
			p.at_start = false
			p.repeatable = false
			return ere_marker(.not_word_begin)
		}
		`w` {
			p.at_start = false
			p.repeatable = true
			return ere_shorthand(false)
		}
		`W` {
			p.at_start = false
			p.repeatable = true
			return ere_shorthand(true)
		}
		`s` {
			p.at_start = false
			p.repeatable = true
			return ere_space_class(false)
		}
		`S` {
			p.at_start = false
			p.repeatable = true
			return ere_space_class(true)
		}
		`0`...`9` {
			// A back reference. csplit refuses them, so this does too, with the same
			// wording.
			return error(ere_bad_back_reference)
		}
		else {
			p.at_start = false
			p.repeatable = true
			return ere_literal(b)
		}
	}
}

// parse_group reads the body of a \( ... \) group.
fn (mut p EreParser) parse_group() !&EreNode {
	saved := p.at_start
	p.at_start = true
	p.repeatable = false
	inner := p.parse_alt() or { return err }
	p.at_start = saved
	p.repeatable = true
	if !p.at_close_group() {
		return error(ere_unmatched_open)
	}
	p.pos += 2
	return inner
}

// ere_shorthand builds the class behind \w and \W.
fn ere_shorthand(negated bool) &EreNode {
	return &EreNode{
		kind:    .class
		negated: negated
		spans:   [ere_span(`0`, `9`), ere_span(`A`, `Z`), ere_span(`a`, `z`), ere_span(`_`, `_`)]
	}
}

// ere_space_class builds the class behind \s and \S.
fn ere_space_class(negated bool) &EreNode {
	return &EreNode{
		kind:    .class
		negated: negated
		spans:   [ere_span(9, 13), ere_span(` `, ` `)]
	}
}

// parse_bracket reads a [ ... ] bracket expression, expanding any [:name:] classes
// into plain byte ranges so that matching needs no name lookup.
fn (mut p EreParser) parse_bracket() !&EreNode {
	p.pos++ // the [
	mut n := &EreNode{
		kind: .class
	}
	if p.peek_is(`^`) {
		n.negated = true
		p.pos++
	}
	// A ] straight after the [ or the [^ is the character itself.
	mut first := true
	for !p.at_end() {
		if p.peek_is(`]`) && !first {
			p.pos++
			p.at_start = false
			// A bracket expression is something a repetition can attach to, which is
			// what makes "[[:lower:]]\{4\}" four of them rather than a brace.
			p.repeatable = true
			return n
		}
		first = false
		if end := p.find_class_name_end() {
			n.spans << posix_spans(p.pattern[p.pos + 2..end].bytestr()) or {
				return error(ere_bad_class_name)
			}
			p.pos = end + 2
			continue
		}
		lo := p.parse_bracket_char() or { return err }
		// A range needs a - that is not the last character before the ].
		if p.peek_is(`-`) && !p.next_is(`]`) {
			p.pos++
			hi := p.parse_bracket_char() or { return err }
			n.spans << ere_span(lo, hi)
		} else {
			n.spans << ere_span(lo, lo)
		}
	}
	return error(ere_unmatched_bracket)
}

// find_class_name_end returns the index of the :] closing a [: :] class name, or none
// when the [: here is a literal [ followed by a colon.
fn (p EreParser) find_class_name_end() ?int {
	if !p.peek_is(`[`) || !p.next_is(`:`) {
		return none
	}
	mut i := p.pos + 2
	for i + 1 < p.pattern.len {
		if p.pattern[i] == `:` && p.pattern[i + 1] == `]` {
			return i
		}
		i++
	}
	return none
}

// parse_bracket_char reads one character inside a bracket expression, where a
// backslash is only there to make the next character literal.
fn (mut p EreParser) parse_bracket_char() !u8 {
	if p.at_end() {
		return error(ere_unmatched_bracket)
	}
	if !p.peek_is(`\\`) {
		return p.take()
	}
	p.pos++
	if p.at_end() {
		return error(ere_trailing_backslash)
	}
	return p.take()
}
