// fmt -- simple text formatter
module fmt

import common
import flag
import os

const app_name = 'fmt'
const default_width = 75
const default_goal = 93
const tab_width = 8
const white_space = ' \n\f\t\v\r'

// Prefer lines to be LEEWAY % shorter than the maximum width,giving
// room for optimization.
const leeway = 7

// The default secondary indent of tagged paragraph used for unindented
// one-line paragraphs not preceded by any multi-line paragraphs
const default_indent = 3

struct FlagsArgs {
	crown_marg bool
	prefix_str string
	split_only bool
	tagged_par bool
	uniform_sp bool
	width      int
	goal       int
	file_args  []string
}

struct AppState {
	width      int // The only output lines longer than this will each comprise a single word
	goal_width int // The preferred width of text lines, set to LEEWAY % less than max_width
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
	flags_args := process_args(args)
	app_state := make_app_state(flags_args)

	for file in app_state.file_args {
		lines := os.read_lines(file) or { common.exit_with_error_message(fmt.app_name, err.msg()) }
		output << fmt(lines, app_state)
	}
	return output
}

fn fmt(lines []string, app_state AppState) []string {
	mut output := []string{}
	paragraphs := get_paragraphs(lines)

	for paragraph in paragraphs {
		for line in fmt_paragraph(paragraph, app_state) {
			output << line
		}
	}
	return output
}

fn fmt_paragraph(paragraph []string, app_state AppState) []string {
	mut ln := []rune{}
	mut pa := []string{}

	if paragraph.len == 0 {
		return ['']
	}

	for line in paragraph {
		ln << line.runes()

		for ln.len > app_state.width {
			break_index := find_break(ln, app_state.width)
			pa << ln[0..break_index].string()
			ln = ln[break_index + 1..].clone()
		}
		pa << ln.string()
		ln = []
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
	return match c {
		` `, `\f` { true }
		else { false }
	}
}

fn get_paragraphs(lines []string) [][]string {
	mut index := 0
	mut paragraphs := [][]string{len: 1, init: []string{}}

	for line in lines {
		ln := line.trim_right(fmt.white_space)
		if ln.len == 0 {
			index += 2
			paragraphs << []string{}
			paragraphs << []string{}
			continue
		}
		paragraphs[index] << ln
	}
	// println(paragraphs)
	return paragraphs
}

fn process_args(args []string) FlagsArgs {
	mut fp := common.flag_parser(args)
	fp.application(fmt.app_name)
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
	width := fp.int('width', `w`, fmt.default_width, 'maximum line width (default of ${fmt.default_width} columns)')
	goal := fp.int('goal', `g`, fmt.default_goal, 'goal width (default of ${fmt.default_goal}% of width)')

	help := fp.bool('help', 0, false, 'display this help')
	version := fp.bool('version', 0, false, 'output version information')

	file_args := fp.finalize() or { common.exit_with_error_message(fmt.app_name, err.msg()) }

	if help {
		success_exit(fp.usage())
	}

	if version {
		success_exit('${fmt.app_name} ${common.coreutils_version()}')
	}

	return FlagsArgs{
		crown_marg: crown_marg
		prefix_str: prefix_str
		split_only: split_only
		tagged_par: tagged_par
		uniform_sp: uniform_sp
		width: width
		goal: goal
		file_args: file_args
	}
}

fn make_app_state(flags_args FlagsArgs) AppState {
	app_state := AppState{
		width: flags_args.width
		goal_width: flags_args.goal
		file_args: flags_args.file_args
	}

	return app_state
}

@[noreturn]
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}