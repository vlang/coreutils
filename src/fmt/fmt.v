// fmt -- V version of POSIX fmt that works with UNICODE
import common
import flag
import io
import os

const app_name = 'fmt'
const space = ' '
const tab_width = 8
const tagged_indent = 4
const default_width = 75
const white_space = ' \n\f\t\v\r'
const end_of_sentence = [`.`, `!`, `?`]

struct App {
	crown_marg bool
	prefix_str string
	split_only bool
	tagged_par bool
	uniform_sp bool
	width      int
	file_args  []string
}

struct Paragraph {
mut:
	prefix       bool
	crown_indent int      = -1
	lines        []string = []string{}
}

fn main() {
	run_fmt(os.args, fn (s string) {
		println(s)
	})
}

fn run_fmt(args []string, out_fn fn (string)) {
	app := process_args(args)

	for file in app.file_args {
		lines := read_all_lines(file)
		fmt(lines, app, out_fn)
	}
}

fn read_all_lines(file string) []string {
	return if file == '-' {
		mut br := io.new_buffered_reader(io.BufferedReaderConfig{ reader: os.stdin() })
		read_lines(mut br)
	} else {
		os.read_lines(file) or { common.exit_with_error_message(app_name, err.msg()) }
	}
}

fn fmt(lines []string, app App, out_fn fn (string)) {
	paragraphs := get_paragraphs(lines, app)

	for paragraph in paragraphs {
		fmt_paragraph(paragraph, app, out_fn)
	}
}

fn fmt_paragraph(paragraph Paragraph, app App, out_fn fn (string)) {
	mut ta := ''

	if paragraph.lines.len == 0 {
		out_fn('')
		return
	}

	mut first_line := true
	mut indent := ' '.repeat(get_indent(paragraph.lines[0])).runes()

	// join all lines in paragraph into a single string
	for line in paragraph.lines {
		mut l := line.clone()
		// remove indents from all but first line
		if !first_line && indent.len > 0 {
			l = l.trim_left(indent.string())
		}
		// add prefix string
		if first_line && paragraph.prefix {
			l = app.prefix_str + l
		}
		ta += l + ' '
		// add extra space for end of sentence punctuation
		if l.len > 0 && l.runes().last() in end_of_sentence {
			ta += ' '
		}
		first_line = false
	}

	if app.uniform_sp {
		ta = ta.after(app.prefix_str)
		sp := ta.split(' ')
		ns := sp.filter(it.len > 0)
		ta = ns.join(' ')
		ta = app.prefix_str + indent.string() + ta
	}

	mut rn := ta.runes()

	if paragraph.crown_indent != -1 {
		indent = ' '.repeat(paragraph.crown_indent).runes()
	} else if app.tagged_par {
		indent = ' '.repeat(indent.len + tagged_indent).runes()
	}

	for rn.len > app.width {
		mut break_index := find_break(rn, app.width)
		slice := rn[0..break_index].string()
		out_fn(slice)
		rn = rn[break_index + 1..].clone()
		for rn.len > 0 && is_white_space(rn[0]) {
			rn.delete(0)
		}
		rn.prepend(indent)
		if paragraph.prefix {
			rn.prepend(app.prefix_str.runes())
		}
	}

	last := rn.string().trim_right(white_space)

	if last.len > 0 {
		out_fn(rn.string().trim_right(white_space))
	}
}

fn find_break(ln []rune, max int) int {
	assert ln.len > max
	mut idx := max

	for !is_white_space(ln[idx]) && idx > 0 {
		idx -= 1
	}

	// no whitespace in line so split at max
	if idx == 0 {
		idx = max
	}

	return idx
}

fn is_white_space(c rune) bool {
	return white_space.contains(c.str())
}

// Breaks lines into logical unformatted paragraphs
//
// A paragraph consists of a maximal number of non-blank
// (excluding any prefix) lines subject to:
//
// * In split mode, a paragraph is a single non-blank line.
// * In crown mode, the second and subsequent lines must have the
//   same indentation, but possibly different from the indent of
//   the first line.
// * Tagged mode is similar, but the first and second lines must
//   have different indentations.
// * Otherwise, all lines of a paragraph must have the same indent.
//
// If a prefix is in effect, it must be present at the same indent
// for each line in the paragraph.
fn get_paragraphs(lines []string, app App) []Paragraph {
	if app.split_only {
		return get_paragraphs_split_only(lines)
	}

	mut last_indent := -1
	mut paragraphs := []Paragraph{len: 1, init: Paragraph{}}

	for line in lines {
		ln := detab(line.trim_right(white_space))

		// Blank line
		if ln.len == 0 {
			paragraphs << Paragraph{}
			paragraphs << Paragraph{}
			last_indent = -1
			continue
		}

		has_prefix := app.prefix_str.len > 0 && ln.starts_with(app.prefix_str)
		np := if has_prefix { ln.after(app.prefix_str) } else { ln }

		indent := get_indent(np)
		if last_indent == -1 {
			last_indent = indent
		}

		if last_indent != indent {
			last_indent = indent
			if app.crown_marg && paragraphs.last().crown_indent == -1 {
				paragraphs.last().crown_indent = indent
			} else {
				paragraphs << Paragraph{
					prefix:       has_prefix
					crown_indent: if app.crown_marg { indent } else { -1 }
					lines:        [np]
				}
				continue
			}
		}

		paragraphs.last().prefix = has_prefix
		paragraphs.last().lines << np
	}
	// println(paragraphs)
	return paragraphs
}

fn get_paragraphs_split_only(lines []string) []Paragraph {
	mut paragraphs := []Paragraph{}
	for line in lines {
		ln := detab(line.trim_right(white_space))
		lf := if ln.len == 0 { []string{} } else { []string{len: 1, init: ln} }
		paragraphs << Paragraph{
			lines: lf
		}
	}
	// println(paragraphs)
	return paragraphs
}

fn get_indent(line string) int {
	ln := line.runes()
	mut pos := 0
	for pos < ln.len && is_white_space(ln[pos]) {
		pos++
	}
	return pos
}

fn process_args(args []string) App {
	mut fp := common.flag_parser(args)
	fp.application(app_name)
	fp.description('Simple text formatter')
	pad := common.eol() + flag.space

	crown_marg := fp.bool('crown-margin', `c`, false,
		'preserve the indentation of the first two lines within' +
		'${pad}a paragraph, and align the left margin of each' +
		'${pad}subsequent line with that of the second line')
	prefix_str := fp.string('prefix', `p`, '',
		'reformat only lines beginning with STRING, reattaching ' +
		'${pad}the prefix to reformatted lines')
	split_only := fp.bool('split-only', `s`, false, 'split long lines, but do not refill')
	tagged_par := fp.bool('tagged-paragraph', `t`, false, 'indentation of first line different from second')
	uniform_sp := fp.bool('uniform-spacing', `u`, false, 'one space between words')
	width := fp.int('width', `w`, default_width, 'maximum line width (default of ${default_width} columns)')

	help := fp.bool('help', 0, false, 'display this help')
	version := fp.bool('version', 0, false, 'output version information')

	file_args := fp.finalize() or { common.exit_with_error_message(app_name, err.msg()) }

	if help {
		success_exit(fp.usage())
	}

	if version {
		success_exit('${app_name} ${common.coreutils_version()}')
	}

	return App{
		crown_marg: crown_marg
		prefix_str: prefix_str
		split_only: split_only
		tagged_par: tagged_par
		uniform_sp: uniform_sp
		width:      width
		file_args:  if file_args.len > 0 { file_args } else { ['-'] }
	}
}

fn read_lines(mut br io.BufferedReader) []string {
	mut lines := []string{}
	for {
		lines << br.read_line() or { break }
	}
	return lines
}

fn detab(s string) string {
	mut output := ''
	mut count := 0
	runes := s.runes()

	for r in runes {
		if r == `\t` {
			for {
				output += space
				count += 1
				if count % tab_width == 0 {
					break
				}
			}
		} else {
			output += r.str()
			count += 1
		}
	}
	return output
}

@[noreturn]
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}
