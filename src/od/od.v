module main

import io
import os
import common

// One `-t` letter: how to print one unit, and how many bytes it consumes.
struct Fmt {
mut:
	kind string // a c b o d x u
	// The unit size GNU prints when the letter carries no digit: two for the
	// numeric formats, one for the two character formats. `-tx` is 4 and `-tx2` is
	// 2, which is the one case where a bare letter is wider than the size asked
	// for, because it reads a machine word.
	size     int
	signed   bool
	has_wide bool
}

// Carried across files: GNU numbers the bytes of every operand as one stream, and
// collapses a repeated line only against the line printed just before it.
struct Printer {
mut:
	prev    string
	starred bool
	base    string
	verbose bool
	fmts    []Fmt
}

// The C0 names GNU prints for `-a`. Measured: 0x00 -> nul, 0x0a -> nl, 0x7f -> del.
const control_names = [
	'nul',
	'soh',
	'stx',
	'etx',
	'eot',
	'enq',
	'ack',
	'bel',
	'bs',
	'ht',
	'nl',
	'vt',
	'ff',
	'cr',
	'so',
	'si',
	'dle',
	'dc1',
	'dc2',
	'dc3',
	'dc4',
	'nak',
	'syn',
	'etb',
	'can',
	'em',
	'sub',
	'esc',
	'fs',
	'gs',
	'rs',
	'us',
	'sp',
]

const hex_digits = '0123456789abcdef'

// GNU wraps at sixteen bytes whether the unit is one or two bytes, so the line
// width does not change with the format. Measured on a 40 byte file.
const bytes_per_line = 16

// V's `fmt` cannot be imported here: `src/fmt` shadows it for every tool that
// lives under `src/`, so the base conversion is spelled out here instead.
// `width` zero pads; `unit_width` does the spacing, so a width of zero means the
// caller wants the digits at their natural length.
fn base_str(v u64, base u8, width int) string {
	mut n := v
	mut out := if n == 0 { '0' } else { '' }
	for n > 0 {
		// A slice, not `hex_digits[i].str()`: the index yields a u8 and `.str()`
		// would give the decimal code, turning "61" into "5449".
		i := int(n % u64(base))
		out = hex_digits[i..i + 1] + out
		n /= u64(base)
	}
	for out.len < width {
		out = '0' + out
	}
	return out
}

// The sign goes inside the field's width, so a negative value never pushes the line
// out: `-td1` gives `   97` and `   -1`, `-td2` gives `    97` and `  -158`.
fn signed_text(f Fmt, data []u8, pos int, pad int) string {
	n := word(data, pos, f.size)
	mut sign := ''
	mut v := n
	if f.size > 1 {
		// The sign is the loaded word's own top bit, which is why `-td` and `-td4`
		// agree on 61 00 62 ff 63 0a: both load the same four bytes and read
		// 0xff620061, while `-td2` loads 0x0061 and stays positive. Measured.
		limit := u64(1) << (8 * f.size - 1)
		if n >= limit {
			sign = '-'
			v = (u64(1) << (8 * f.size)) - n
		}
	} else if f.size == 1 && data[pos] > 127 {
		sign = '-'
		v = 256 - u64(data[pos])
	}
	return lpad(sign + base_str(v, 10, 0), pad)
}

// Host byte order, measured on 41 42: `-tx2` prints `4241` and `-tx4` prints
// `00004241`. The unit is loaded the way the machine loads a load, so the last
// byte read ends up most significant, which is why `-tx` on 61 00 62 ff 63 0a
// gives `ff620061`.
fn word(data []u8, from int, size int) u64 {
	mut at := from
	mut v := u64(0)
	mut shift := u32(0)
	for _ in 0 .. size {
		if at < data.len {
			v |= u64(data[at]) << shift
			at++
		}
		shift += 8
	}
	return v
}

fn escape_char(b u8) string {
	match b {
		0x00 { return '\\0' }
		0x07 { return '\\a' }
		0x08 { return '\\b' }
		0x09 { return '\\t' }
		0x0a { return '\\n' }
		0x0b { return '\\v' }
		0x0c { return '\\f' }
		0x0d { return '\\r' }
		else {}
	}
	if b < 0x20 || b >= 0x7f {
		return base_str(u64(b), 8, 3)
	}
	// `[b].bytestr()` is the conversion that yields the character; `b.str()` gives "97"
	// and `[b].str()` gives "[97]".
	return [b].bytestr()
}

// GNU's `-a` names the C0 range and `del`; printable bytes print as themselves.
fn control_name(b u8) string {
	if b < 0x20 {
		return control_names[b]
	}
	if b >= 0x7f {
		return 'del'
	}
	return [b].bytestr()
}

// Right align with spaces, which is what the two character formats need: `-tc`
// prints `  a` beside `  \0`, and `-td1` prints `   97` beside `   -1`.
fn lpad(s string, width int) string {
	mut out := s
	for out.len < width {
		out = ' ' + out
	}
	return out
}

// Two different widths, and conflating them is what made `-tx1` print eight digit
// bytes. This one is the zero pad on the digits themselves; `unit_column` is how
// wide the field is set in the line. All figures measured on 61 00 62 ff 63 0a.
fn zero_pad_to(f Fmt) int {
	return match f.kind {
		'a', 'c' { 0 }
		// Octal, hex and `-b` zero pad. Decimal does not: `-td2` prints `    97` and
		// `-tu2` prints ` 65378`, so the digits go through untouched and the column
		// does the spacing. Measured on 61 00 62 ff 63 0a.
		'b' { 3 }
		// A machine word prints at its own length: `-to` gives `37730400141` in
		// eleven columns, which is fewer than twelve would be, so the pad is not
		// simply three per byte. Measured on 61 00 62 ff 63 0a.
		'o' {
			if f.has_wide { 11 } else { 3 * f.size }
		}
		'd', 'u' { 0 }
		else { 2 * f.size }
	}
}

// The column a field is set in. A sized format is as wide as the value it can
// print, since nothing is wider: `-tx1` two, `-tx2` four, `-to2` six, `-td2` five.
// A machine word unit is wider, because the sign and the bytes past the end can
// push it out: `-td` sets eleven so `-10354591` and `2659` line up, and `-tx` sets
// eight. `-a` and `-c` are three. Measured on 61 00 62 ff 63 0a.
fn unit_column(f Fmt) int {
	return match f.kind {
		'a', 'c' { 3 }
		'b' { 3 }
		'o' {
			if f.has_wide { 11 } else { 3 * f.size }
		}
		'd', 'u' {
			if f.has_wide { 11 } else { 5 }
		}
		else {
			if f.has_wide { 8 } else { 2 * f.size }
		}
	}
}

fn unit_text(f Fmt, data []u8, pos int) string {
	pad := zero_pad_to(f)
	match f.kind {
		'a' { return control_name(data[pos]) }
		'c' { return escape_char(data[pos]) }
		'b' { return base_str(u64(data[pos]), 8, pad) }
		'o' { return base_str(word(data, pos, f.size), 8, pad) }
		'd' { return signed_text(f, data, pos, pad) }
		'u' { return base_str(word(data, pos, f.size), 10, pad) }
		else { return base_str(word(data, pos, f.size), 16, pad) }
	}
}

fn offset_text(off int, base string) string {
	return match base {
		'd' { base_str(u64(off), 10, 7) }
		'x' { base_str(u64(off), 16, 6) }
		'n' { '' }
		else { base_str(u64(off), 8, 7) }
	}
}

// `u8.str()` is the decimal code, not the character, so a format letter must be
// spelled out rather than converted from its byte.

// `-tx2`, `-t o2`, `-tac`. A digit sets the unit size for the letters before it,
// except for the three formats that are only ever one byte wide.
fn parse_spec(spec string) ![]Fmt {
	mut fmts := []Fmt{}
	for ch in spec {
		match ch {
			`0`...`9` {
				if fmts.len > 0 {
					last := fmts.len - 1
					n := int(ch - `0`)
					if fmts[last].has_wide {
						// A bare `o`, `d`, `u` and `x` are machine words until a digit narrows
						// them: `-tx` is 4 on this host, `-tx2` is 2. The word flag has to be
						// cleared as well as the size, because it is what widens the column:
						// `-td2` is five columns wide and `-td` is eleven.
						fmts[last].size = n
						fmts[last].has_wide = false
					} else if n == 1 || n == 2 || n == 4 {
						fmts[last].size = n
					} else {
						return error("invalid type string '${spec}'")
					}
				}
			}
			`a` {
				fmts << Fmt{
					kind: 'a'
					size: 1
				}
			}
			`b` {
				return error("invalid character '${[ch].bytestr()}' in type string '${spec}'")
			}
			`c` {
				fmts << Fmt{
					kind: 'c'
					size: 1
				}
			}
			`o` {
				// A bare `o` reads a machine word, like a bare `x`.
				fmts << Fmt{
					kind:     'o'
					size:     4
					has_wide: true
				}
			}
			`d` {
				fmts << Fmt{
					kind:     'd'
					size:     4
					has_wide: true
					signed:   true
				}
			}
			`x` {
				// A bare `x` reads a machine word: 4 bytes on this host.
				fmts << Fmt{
					kind:     'x'
					size:     4
					has_wide: true
				}
			}
			`u` {
				fmts << Fmt{
					kind:     'u'
					size:     4
					has_wide: true
				}
			}
			else {
				return error("invalid character '${[ch].bytestr()}' in type string '${spec}'")
			}
		}
	}
	if fmts.len == 0 {
		return error('no type specifier given')
	}
	return fmts
}

// `upto` is the absolute offset the dump stops at, or -1 for the whole stream, so
// that `-N` cuts mid line: `-N2 -j1` ends after one unit at offset 3, not at the
// end of the sixteen byte line.
// Fields arrive the right width for every format except the signed decimal, where
// the value's own padding cannot know whether the sign will be there. So `-td1`
// pads its digits to five and this puts the sign in front, making `-1` six wide,
// which is what GNU does: measured `   97` and `   -1` beside each other.
// `-a` and `-c` right align in three columns, so `  a` sits beside `  \0`, and the
// numeric ones are already the right width from their zero padding. Only the
// decimal formats need a second pass, because a signed value is one wider than
// its unsigned column and `-td1` prints `   97` beside `   -1`. Measured.
// Every row of a multi format line as one string, so the `*` collapse can compare
// the line as a whole rather than one format's half of it.
fn text_of(passes [][]string, fmts []Fmt) string {
	mut out := []string{cap: passes.len}
	for pass, row in passes {
		out << join_fields(row, fmts[pass])
	}
	return out.join('|')
}

fn join_fields(fields []string, f Fmt) string {
	// Only the two character formats are space padded. `-b` zero pads like the
	// numeric ones, which is what keeps `-b` giving `000` where `-tb` would have
	// given `  0`. Measured.
	if f.kind == 'a' || f.kind == 'c' {
		mut out := []string{cap: fields.len}
		for x in fields {
			out << lpad(x, 3)
		}
		return out.join(' ')
	}
	if f.kind == 'd' || f.kind == 'u' {
		col := unit_column(f)
		mut out := []string{cap: fields.len}
		for x in fields {
			out << lpad(x, col)
		}
		return out.join(' ')
	}
	return fields.join(' ')
}

fn (mut p Printer) write(data []u8, base_off int, upto int, skip int) {
	base := p.base
	// `base_off` is where this part starts in the stream and `skip` is how much of it
	// was already consumed by `-j`, so the offset the dump ends at is
	// `base_off + skip + bytes of this part`. Measured: `-j2` on a six byte file ends
	// at `0000006`, not at the eight the part's own length would give.
	mut stop := data.len
	if upto >= 0 {
		stop = upto - base_off
		if stop > data.len {
			stop = data.len
		}
	}
	for start := 0; start < stop; start += bytes_per_line {
		end := if start + bytes_per_line < stop {
			start + bytes_per_line
		} else {
			stop
		}
		// Filled once per format over the whole line, so `-tac` gets six fields rather
		// than three: each format walks the line by itself and the results are kept
		// in format order.
		mut passes := [][]string{cap: p.fmts.len}
		for f in p.fmts {
			mut row := []string{cap: (end - start) / f.size}
			for pos := start; pos < end; pos += f.size {
				row << unit_text(f, data, pos)
			}
			passes << row
		}
		// One line per format, not one line of everything: `-tac` prints the `-a`
		// pass on the first line and the `-c` pass on the second, measured. So each
		// format gets its own set of columns rather than sharing the line, and the
		// line is filled once per format so `-tac` gets six fields rather than three.
		// The `*` collapse holds a run across the whole multi format group: `-tac` over 40
		// copies of 0x41 prints sixteen rows of each format, then one `*`, then the
		// remaining eight of each. So a repeated group prints nothing at all rather
		// than half of it. Measured.
		// One row per format, so `-tac` prints two lines per sixteen bytes, and the `*`
		// collapse compares the whole group: a repeat prints nothing at all. The first
		// row carries the address and the rest are indented to where it would have been.
		head := offset_text(base_off + start, p.base)
		indent := if head == '' { ' ' } else { ' '.repeat(head.len + 1) }
		joined := text_of(passes, p.fmts)
		if !p.verbose && joined == p.prev {
			if !p.starred {
				println('*')
				p.starred = true
			}
			continue
		}
		p.starred = false
		p.prev = joined
		for pass, row in passes {
			println((if pass == 0 { head + ' ' } else { indent }) +
				join_fields(row, p.fmts[pass]))
		}
	}
	// GNU closes a dump with a line holding only the final offset, unless the
	// address was suppressed: measured on 6 bytes and on `-N4`, both of which end
	// in a bare offset. With `-An` it prints nothing extra.
	// The closing offset line, which carries the offset the dump ended at, not the one
	// it started at: `-j 40` on a 40 byte file prints `0000050` alone. With no
	// address requested there is no closing line either. Measured.
	// The closing offset is where the dump ended in the stream, not where this part
	// ended: `-j2` on a six byte file prints `0000006` because two bytes were
	// skipped and four dumped, and `-j 40` on a 40 byte file prints `0000050`.
	// Measured.
	if base != 'n' {
		println(offset_text(skip + stop, base))
	}
}

// A scalar `mut` parameter is not allowed in V, so the three settings travel in
// one mutable struct.
struct Settings {
mut:
	skip  int
	limit int
	base  string
}

// Applied the moment the value is read, because `-j1 -N2` names two different
// options and a single slot for the pending value lost whichever came first.
fn apply_option(opt u8, value string, mut s Settings) !void {
	match opt {
		`N` {
			if !numeric_run(value) {
				return error("invalid -N argument '${value}'")
			}
			s.limit = value.int()
		}
		`j` {
			if !numeric_run(value) {
				return error("invalid -j argument '${value}'")
			}
			s.skip = value.int()
		}
		`A` {
			if value.len != 1 || value[0] !in [`o`, `d`, `x`, `n`] {
				return error("invalid -A argument '${value}'")
			}
			s.base = value
		}
		else {}
	}
}

fn numeric_run(s string) bool {
	if s.len == 0 {
		return false
	}
	for ch in s {
		if !ch.is_digit() {
			return false
		}
	}
	return true
}

const version_text = 'od (V coreutils) ${common.version}'

// The arguments are read by hand rather than through the shared flag parser. The
// parser reads `-tx2` as a clustered short option group and swallows the type
// letters, and it panics on `-j` outright because no option is registered for it.
// Handing it the command line is what makes it print `--help` and `--version`, so
// those two are answered here and the parser is not used at all.
fn main() {
	if os.args[1..].any(it == '--version') {
		println(version_text)
		return
	}
	if os.args[1..].any(it == '--help') {
		println('Usage: od [OPTION]... [FILE]...')
		println('Print the contents of FILE in octal and other formats.')
		println('')
		println(common.coreutils_footer())
		return
	}

	mut set := Settings{
		limit: -1
		base:  'o'
	}
	mut verbose := false

	mut fmts := []Fmt{}
	mut files := []string{}
	mut literal := false
	mut takes_value := u8(0)
	for p in os.args[1..] {
		// The value of a separated option (`-N 4`) is consumed here; an attached
		// one (`-N4`) is recognised further down and applied in the same pass.
		if takes_value != 0 {
			apply_option(takes_value, p, mut set) or {
				eprintln('od: ' + err.msg())
				exit(1)
			}
			takes_value = 0
			continue
		}
		if literal || !p.starts_with('-') || p.len < 2 {
			files << p
			continue
		}
		if p == '--' {
			literal = true
			continue
		}
		// `-t` is the only short option GNU takes with a separate argument, and
		// it is read by hand; everything else is a type letter. `-x` and `-b` are
		// bare letters, so they need no handling here.
		// `-N`, `-j` and `-A` take their value either attached (`-N4`) or as the next
		// word (`-N 4`), and GNU also accepts `-t` with the letters split off. The
		// flag parser only copes with the separated form, so every word is read
		// here and the parser is never asked about them.
		if p == '-N' || p == '-j' || p == '-A' {
			takes_value = p[1]
			continue
		}
		if p.len > 1 && p[1] in [`N`, `j`, `A`] {
			apply_option(p[1], p[2..], mut set) or {
				eprintln('od: ' + err.msg())
				exit(1)
			}
			continue
		}
		if p == '-v' {
			verbose = true
			continue
		}
		mut letters := p[1..]
		// `-b` is a format in its own right, but GNU rejects `b` inside a `-t` string, so
		// the two spellings are not the same thing. Measured: `-b` prints and `-tb` exits 1.
		if letters[0] == `b` {
			fmts << Fmt{
				kind: 'b'
				size: 1
			}
			continue
		}
		if letters[0] == `t` {
			letters = letters[1..]
		}
		for f in parse_spec(letters) or {
			eprintln('od: ' + err.msg())
			exit(1)
		} {
			fmts << f
		}
	}
	if set.skip < 0 || set.limit < -1 {
		eprintln('od: invalid argument')
		exit(1)
	}
	if fmts.len == 0 {
		// GNU's default, measured: two byte units printed as six digit octal.
		fmts = [Fmt{
			kind: 'o'
			size: 2
		}]
	}

	mut printer := Printer{
		base:    set.base
		verbose: verbose
		fmts:    fmts
	}
	mut off := 0
	mut left := set.limit
	mut skip_left := set.skip
	for path in files {
		mut part := []u8{}
		if path == '' {
			part = io.read_all(io.ReadAllConfig{}) or { []u8{} }
		} else {
			if !os.exists(path) {
				eprintln('od: ${path}: No such file or directory')
				exit(1)
			}
			// `os.read_file` is the text form in this V and translates CRLF on Windows,
			// which would corrupt the very bytes od exists to show.
			part = os.read_bytes(path)!
		}
		if skip_left > 0 {
			// A skip exactly equal to the length is not an error: `-j 40` on a 40
			// byte file prints the closing offset `0000050` and exits 0. Only a skip
			// past the end fails, which measured on `-j 40` against a six byte file
			// gives `cannot skip past end of combined input`.
			if skip_left > part.len {
				eprintln('od: cannot skip past end of combined input')
				exit(1)
			}
			// `part[part.len..]` is out of range even though the offset is legal,
			// which panicked on an exact skip, so the slice is guarded here.
			if skip_left == part.len {
				part = []
			} else {
				part = part[skip_left..]
			}
			off += skip_left
			skip_left = 0
		}
		mut stop := -1
		if left >= 0 {
			stop = off + left
			take := stop - off
			if take < part.len {
				part = part[..take]
			}
			left -= part.len
		}
		printer.write(part, off, stop, set.skip)
		off += part.len
		if left == 0 {
			break
		}
	}
}
