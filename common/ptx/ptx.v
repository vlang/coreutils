module ptx

import common

const app_name = 'ptx'

pub struct Settings {
pub mut:
	width           int = 72
	gap             int = 3
	ignore_case     bool // -f
	references      bool // -r
	auto_reference  bool // -A
	truncate_marker string = '/' // -F
	word_regexp     string // -W
	sentence_regexp string // -S
	macro_name      string // -M
	typeset         bool   // -t / -G
	only_file       string // -o
	ignore_file     string // -i
	break_file      string // -b
	operands        []string
}

// Entry is one output row: a keyword and the context on either side.
pub struct Entry {
pub mut:
	keyword string
	before  string
	after   string
}

// build_entries turns one text into one entry per keyword occurrence. The
// default keyword is a run of letters, which is GNU's default word regexp:
// measured against GNU 9.4, "hello, world! it's 42nd" produces the keywords
// hello, it, nd, s and world — "42" is context, not a keyword, so digits are
// excluded from the default word.
pub fn build_entries(text string, set Settings) []Entry {
	mut entries := []Entry{}
	for line in text.split('\n') {
		if line.trim_space() == '' {
			continue
		}
		mut i := 0
		for i < line.len {
			word, end := word_at(line, i)
			if word == '' {
				i++
				continue
			}
			entries << Entry{
				keyword: word
				before:  rtrim(line[..i], ` `)
				after:   ltrim(line[end..], ` `)
			}
			i = end
		}
	}
	return entries
}

fn word_at(line string, i int) (string, int) {
	is_word := fn (c u8) bool {
		return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
	}
	if !is_word(line[i]) {
		return '', i
	}
	mut end := i
	for end < line.len && is_word(line[end]) {
		end++
	}
	return line[i..end], end
}

// sort_entries orders the index by keyword, which is the only ordering GNU
// gives the permuted index.
pub fn sort_entries(mut entries []Entry) {
	entries.sort_with_compare(fn (a &Entry, b &Entry) int {
		if a.keyword < b.keyword {
			return -1
		}
		if a.keyword > b.keyword {
			return 1
		}
		return 0
	})
}

// render lays the entries out. The measured rule is:
//
//	tail right-justified in line_width / 2, then gap spaces, then the keyword
//	left-justified to the widest keyword, then the head.
//
// Putting every keyword at the same column is what makes a permuted index
// readable: each row is centred on a different word.
pub fn render(entries []Entry, set Settings) []string {
	if entries.len == 0 {
		return []string{}
	}
	mut keyword_w := 0
	for e in entries {
		if e.keyword.len > keyword_w {
			keyword_w = e.keyword.len
		}
	}
	tail_w := set.width / 2

	mut rows := []string{cap: entries.len}
	for e in entries {
		mut tail := e.before
		mut head := e.after
		if tail.len > tail_w {
			// A tail that is too long loses its start, keeping the words
			// nearest the keyword, and gains the truncation marker.
			mut keep := tail_w - set.truncate_marker.len
			if keep < 0 {
				keep = 0
			}
			tail = tail[tail.len - keep..] + set.truncate_marker
		}
		// The head takes whatever is left of the line after the tail, the gap
		// and the keyword. Truncating it to the keyword width instead would
		// cut "beta gamma" to "beta " in the default three-word case.
		mut head_w := set.width - tail_w - set.gap - keyword_w - 1
		if head_w < 0 {
			head_w = 0
		}
		if head.len > head_w {
			head = head[..head_w]
		}
		// The keyword is not padded: GNU puts exactly one space between the
		// keyword and its head, so a short keyword does not shift the head
		// right. When the head is empty the last word leaves no trailing
		// space either.
		row := if head == '' {
			'${rjust(tail, tail_w)}${' '.repeat(set.gap)}${e.keyword}'
		} else {
			'${rjust(tail, tail_w)}${' '.repeat(set.gap)}${e.keyword} ${head}'
		}
		rows << row
	}
	return rows
}

fn rjust(s string, w int) string {
	if s.len >= w {
		return s
	}
	return ' '.repeat(w - s.len) + s
}

fn ljust(s string, w int) string {
	if s.len >= w {
		return s
	}
	return s + ' '.repeat(w - s.len)
}

fn rtrim(s string, c u8) string {
	mut out := s
	for out.len > 0 && out[out.len - 1] == c {
		out = out[..out.len - 1]
	}
	return out
}

fn ltrim(s string, c u8) string {
	mut out := s
	for out.len > 0 && out[0] == c {
		out = out[1..]
	}
	return out
}

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut operands := []string{}

	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--help' {
			print_help()
			exit(0)
		}
		if a == '--version' {
			println('ptx (V coreutils) ${common.version}')
			exit(0)
		}
		if a == '--' {
			operands << args[i + 1..]
			break
		}
		if a.starts_with('--width=') {
			s.width = a['--width='.len..].int()
			continue
		}
		if a.starts_with('--gap-size=') {
			s.gap = a['--gap-size='.len..].int()
			continue
		}
		if a.starts_with('--flag-truncation=') {
			s.truncate_marker = a['--flag-truncation='.len..]
			continue
		}
		if a.starts_with('--word-regexp=') {
			s.word_regexp = a['--word-regexp='.len..]
			continue
		}
		if a.starts_with('--sentence-regexp=') {
			s.sentence_regexp = a['--sentence-regexp='.len..]
			continue
		}
		if a.starts_with('-') && a.len > 1 && a != '-' {
			mut j := 1
			for j < a.len {
				c := a[j]
				match c {
					`f` { s.ignore_case = true }
					`A` { s.auto_reference = true }
					`G`, `t` { s.typeset = true }
					`r` { s.references = true }
					`g` {
						v, next := take_value(args, i, a, j)
						i = next
						s.gap = v.int()
						j = a.len
						continue
					}
					`w` {
						v, next := take_value(args, i, a, j)
						i = next
						s.width = v.int()
						j = a.len
						continue
					}
					`F` {
						v, next := take_value(args, i, a, j)
						i = next
						s.truncate_marker = v
						j = a.len
						continue
					}
					`W` {
						v, next := take_value(args, i, a, j)
						i = next
						s.word_regexp = v
						j = a.len
						continue
					}
					`S` {
						v, next := take_value(args, i, a, j)
						i = next
						s.sentence_regexp = v
						j = a.len
						continue
					}
					`o` {
						v, next := take_value(args, i, a, j)
						i = next
						s.only_file = v
						j = a.len
						continue
					}
					`i` {
						v, next := take_value(args, i, a, j)
						i = next
						s.ignore_file = v
						j = a.len
						continue
					}
					`b` {
						v, next := take_value(args, i, a, j)
						i = next
						s.break_file = v
						j = a.len
						continue
					}
					`d` {}
					else {
						common.exit_with_error_message(app_name, "invalid option -- '${c.ascii_str()}'")
					}
				}
				j++
			}
			continue
		}
		operands << a
	}

	s.operands = operands
	return s
}

// take_value takes the value for an option: the rest of the same word if there
// is one, else the next argument.
fn take_value(args []string, i int, word string, at int) (string, int) {
	rest := word[at + 1..]
	if rest != '' {
		return rest, i
	}
	if i + 1 >= args.len {
		c := word[at]
		common.exit_with_error_message(app_name, "option requires an argument -- '${c.ascii_str()}'")
	}
	return args[i + 1], i + 1
}

fn print_help() {
	println('Usage: ptx [OPTION]... [INPUT]...')
	println('Output a permuted index, including context, of the words in the input files.')
	println('')
	println('  -A, --auto-reference           output automatically generated references')
	println('  -F, --flag-truncation=STRING   use STRING for flagging line truncations')
	println('  -M, --macro-name=STRING        macro name to use instead of xx')
	println('  -W, --word-regexp=REGEXP       use REGEXP to match each keyword')
	println('  -S, --sentence-regexp=REGEXP   for end of lines or end of sentences')
	println('  -b, --break-file=FILE          word break characters in this FILE')
	println('  -f, --ignore-case              fold lower case to upper case for sorting')
	println('  -g, --gap-size=NUMBER          gap size in columns between output fields')
	println('  -i, --ignore-file=FILE         read ignore word list from FILE')
	println('  -o, --only-file=FILE           read only word list from this FILE')
	println('  -r, --references               first field of each line is a reference')
	println('  -w, --width=NUMBER             output width in columns')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
