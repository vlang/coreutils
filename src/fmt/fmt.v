// fmt -- simple text formatter
import common
import flag
import os

const app_name = 'fmt'

struct FmtCmd {
	crown_marg bool
	prefix_str string
	split_only bool
	tagged_par bool
	uniform_sp bool
	width      int
	goal       int
	file_args  []string
}

fn main() {
	run_fmt(os.args)
}

fn run_fmt(args []string) {
	setup(args)
}

fn setup(args []string) FmtCmd {
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
	width := fp.int('width', `w`, 75, 'maximum line width (default of 75 columns)')
	goal := fp.int('goal', `g`, 93, 'goal width (default of 93% of width)')

	help := fp.bool('help', 0, false, 'display this help')
	version := fp.bool('version', 0, false, 'output version information')

	file_args := fp.finalize() or { common.exit_with_error_message(app_name, err.msg()) }

	if help {
		success_exit(fp.usage())
	}

	if version {
		success_exit('${app_name} ${common.coreutils_version()}')
	}

	return FmtCmd{
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

@[noreturn]
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}
