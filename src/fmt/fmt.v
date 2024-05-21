// fmt -- simple text formatter
import common
import flag
import io
import os

const app_name = 'fmt'
const default_width = 75
const tab_width = 8
const white_space = ' \n\f\t\v\r'
const end_of_sentence = [`.`, `!`, `?`]

// The default secondary indent of tagged paragraph used for unindented
// one-line paragraphs not preceded by any multi-line paragraphs
const default_indent = 3

struct App {
	crown_marg bool
	prefix_str string
	split_only bool
	tagged_par bool
	uniform_sp bool
	width      int
	file_args  []string
}

fn main() {
	output := run_fmt(os.args)

	for line in output {
		println(line)
	}
}

fn run_fmt(args []string) []string {
	mut output := []string{}
	app := process_args(args)

	for file in app.file_args {
		lines := read_all_lines(file)
		output << fmt(lines, app)
	}
	return output
}

fn read_all_lines(file string) []string {
	return if file == '-' {
		mut br := io.new_buffered_reader(io.BufferedReaderConfig{ reader: os.stdin() })
		read_lines(mut br)
	} else {
		os.read_lines(file) or { common.exit_with_error_message(app_name, err.msg()) }
	}
}

fn fmt(lines []string, app App) []string {
	mut output := []string{}
	paragraphs := get_paragraphs(lines, app)

	for paragraph in paragraphs {
		for line in fmt_paragraph(paragraph, app) {
			output << line
		}
	}
	return output
}

fn fmt_paragraph(paragraph []string, app App) []string {
	mut ta := ''
	mut pa := []string{}

	if paragraph.len == 0 {
		return ['']
	}

	mut first_line := true
	indent := ' '.repeat(get_indent(paragraph[0])).runes()

	// join all lines with spacing for punchuation and breaks
	for line in paragraph {
		mut l := line.clone()
		if !first_line && indent.len > 0 {
			l = l.trim_left(indent.string())
		}
		ta += l + ' '
		if l.len > 0 && l.runes().last() in end_of_sentence {
			ta += ' '
		}
		first_line = false
	}

	mut ln := ta.runes()

	for ln.len > app.width {
		mut break_index := find_break(ln, app.width)
		pa << ln[0..break_index].string()
		ln = ln[break_index + 1..].clone()
		for ln.len > 0 && is_white_space(ln[0]) {
			ln.delete(0)
		}
		ln.prepend(indent)
	}

	last := ln.string().trim_right(white_space)

	if last.len > 0 {
		pa << ln.string().trim_right(white_space)
	}
	return pa
}

fn find_break(ln []rune, max int) int {
	assert ln.len > max
	mut idx := max

	for !is_white_space(ln[idx]) && idx > 0 {
		idx -= 1
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
fn get_paragraphs(lines []string, app App) [][]string {
	if app.split_only {
		return get_paragraphs_split_only(lines)
	}

	mut index := 0
	mut last_indent := -1
	mut paragraphs := [][]string{len: 1, init: []string{}}

	for line in lines {
		ln := line.trim_right(white_space)

		if ln.len == 0 {
			paragraphs << []string{}
			paragraphs << []string{}
			index += 2
			last_indent = -1
			continue
		}

		indent := get_indent(ln)
		if last_indent == -1 {
			last_indent = indent
		}

		if last_indent != indent {
			paragraphs << []string{}
			index += 1
			paragraphs[index] << ln
			continue
		}

		paragraphs[index] << ln
	}
	// println(paragraphs)
	return paragraphs
}

fn get_paragraphs_split_only(lines []string) [][]string {
	mut paragraphs := [][]string{}
	for line in lines {
		ln := line.trim_right(white_space)
		lf := if ln.len == 0 { []string{} } else { []string{len: 1, init: ln} }
		paragraphs << lf
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
	uniform_sp := fp.bool('uniform-spacing', `u`, false, 'one space between words, two after sentences')
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
		width: width
		file_args: if file_args.len > 0 { file_args } else { ['-'] }
	}
}

fn read_lines(mut br io.BufferedReader) []string {
	mut lines := []string{}
	for {
		lines << br.read_line() or { break }
	}
	return lines
}

@[noreturn]
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}
