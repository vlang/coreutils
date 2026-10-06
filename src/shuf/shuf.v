module main

import os
import flag
import strconv
import common

const app_name = 'shuf'

const app_description = 'Write a random permutation of the input lines to standard output.'

struct Settings {
mut:
	echo                bool
	input_range         string
	head_count          u64
	head_count_given    bool
	output              string
	output_given        bool
	random_source       string
	random_source_given bool
	repeat              bool
	zero_terminated     bool
	operands            []string
}

fn main() {
	settings := args()
	run(settings)
}

// read_lines returns the lines of f, keeping empty lines. A final line without
// a terminator is returned as is; callers add the terminator back.
fn read_lines(mut f os.File, delim u8) []string {
	mut lines := []string{}
	mut buf := []u8{len: 64 * 1024}
	mut line := []u8{}
	for {
		n := f.read(mut buf) or { break }
		for i in 0 .. n {
			b := buf[i]
			if b == delim {
				lines << line.bytestr()
				line = []u8{}
			} else {
				line << b
			}
		}
	}
	if line.len > 0 {
		lines << line.bytestr()
	}
	return lines
}

fn open_operands(operands []string, delim u8) []string {
	mut lines := []string{}
	for operand in operands {
		mut file := os.stdin()
		if operand != '-' {
			file = os.open(operand) or {
				common.exit_with_error_message(app_name,
					'${operand}: ${posix_msg()}')
			}
		}
		lines << read_lines(mut file, delim)
		file.close()
	}
	return lines
}

// parse_range splits LO-HI and returns lo and hi, rejecting anything GNU
// rejects.
fn parse_range(arg string) []u64 {
	parts := arg.split('-')
	if parts.len != 2 || parts[0].len == 0 || parts[1].len == 0 {
		common.exit_with_error_message(app_name, 'invalid input range: ‘${arg}’')
	}
	lo := strconv.atou64(parts[0]) or {
		common.exit_with_error_message(app_name, 'invalid input range: ‘${arg}’')
	}
	hi := strconv.atou64(parts[1]) or {
		common.exit_with_error_message(app_name, 'invalid input range: ‘${arg}’')
	}
	if lo > hi {
		common.exit_with_error_message(app_name, 'invalid input range: ‘${arg}’')
	}
	return [lo, hi]
}

// posix_msg returns the strerror text for the failure that just happened, in
// the form GNU prints it. os.error_posix() returns an error value whose
// interpolation carries V's trailing "; code: N".
fn posix_msg() string {
	return os.error_posix().msg()
}

fn run(settings Settings) {
	if settings.echo && settings.input_range.len > 0 {
		common.exit_with_error_message(app_name, 'cannot combine -e and -i options')
	}
	if !settings.echo && settings.input_range.len == 0 && settings.operands.len > 1 {
		common.exit_with_error_message(app_name, 'extra operand ‘${settings.operands[1]}’')
	}
	if settings.input_range.len > 0 && settings.operands.len > 0 {
		common.exit_with_error_message(app_name, 'extra operand ‘${settings.operands[0]}’')
	}

	delim := if settings.zero_terminated { u8(0) } else { u8(`\n`) }
	mut source := new_randint_source(settings.random_source)
	mut out := os.stdout()

	if settings.output_given {
		out = os.create(settings.output) or {
			common.exit_with_error_message(app_name,
				'${settings.output}: ${posix_msg()}')
		}
	}

	// Collect the input up front, except when -n 0 means nothing is needed.
	mut lines := []string{}
	mut lo := u64(0)
	if settings.echo {
		lines = settings.operands.clone()
	} else if settings.input_range.len > 0 {
		r := parse_range(settings.input_range)
		lo = r[0]
		hi := r[1]
		for i in lo .. hi + 1 {
			lines << i.str()
		}
	} else {
		operands := if settings.operands.len == 0 { ['-'] } else { settings.operands }
		lines = open_operands(operands, delim)
	}

	// -n 0 means output nothing; without -n every line is used.
	count := if settings.head_count_given { settings.head_count } else { u64(lines.len) }
	if count == 0 {
		return
	}

	if settings.repeat {
		if lines.len == 0 {
			common.exit_with_error_message(app_name, 'no lines to repeat')
		}
		for _ in 0 .. count {
			j := int(source.choose(u64(lines.len)))
			out.write_string(lines[j] + delim.ascii_str()) or {
				common.exit_with_error_message(app_name, err.msg())
			}
		}
		return
	}

	ahead := if count < u64(lines.len) { int(count) } else { lines.len }
	if ahead == 0 {
		return
	}

	permutation := randperm_new(mut source, ahead, lines.len)
	for idx in permutation {
		line := lines[int(idx)]
		if line.len > 0 || !settings.zero_terminated {
			out.write_string(line) or {
				common.exit_with_error_message(app_name, err.msg())
			}
		}
		if !line.ends_with(delim.ascii_str()) {
			out.write_string(delim.ascii_str()) or {
				common.exit_with_error_message(app_name, err.msg())
			}
		}
	}
}

// The _opt flag variants are used throughout so that V does not append a
// "(default ...)" note to every option in --help, which GNU does not print.
fn args() Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)
	fp.usage_example('[OPTION]... [FILE]')
	fp.usage_example('-e [OPTION]... [ARG]...')
	fp.usage_example('-i LO-HI [OPTION]...')
	fp.description('')
	fp.description('With no FILE, or when FILE is -, read standard input.')

	mut settings := Settings{}
	settings.echo = fp.bool_opt('echo', `e`, 'treat each ARG as an input line',
		flag.FlagConfig{}) or { false }
	settings.input_range = fp.string_opt('input-range', `i`,
		'treat each number LO through HI as an input line', flag.FlagConfig{
			val_desc: '=LO-HI'
		}) or { '' }

	head_count := fp.string_opt('head-count', `n`, 'output at most COUNT lines',
		flag.FlagConfig{
			val_desc: '=COUNT'
		}) or { '' }
	settings.head_count_given = head_count.len > 0
	if settings.head_count_given {
		settings.head_count = strconv.atou64(head_count) or {
			common.exit_with_error_message(app_name, 'invalid line count: ‘${head_count}’')
		}
	}

	output := fp.string_opt('output', `o`, 'write result to FILE instead of standard output',
		flag.FlagConfig{
			val_desc: '=FILE'
		}) or { '' }
	settings.output_given = output.len > 0
	settings.output = output

	random_source := fp.string_opt('random-source', 0, 'get random bytes from FILE',
		flag.FlagConfig{
			val_desc: '=FILE'
		}) or { '' }
	settings.random_source_given = random_source.len > 0
	settings.random_source = random_source

	settings.repeat = fp.bool_opt('repeat', `r`, 'output lines can be repeated',
		flag.FlagConfig{}) or { false }
	settings.zero_terminated = fp.bool_opt('zero-terminated', `z`,
		'line delimiter is NUL, not newline', flag.FlagConfig{}) or { false }

	settings.operands = fp.remaining_parameters()
	return settings
}
