module main

import common
import math
import os
import regex

const app = common.CoreutilInfo{
	name:        'truncate'
	description: 'shrink or extend the size of a file to the specified size'
}

const default_block_size = 4096
// Convert metric prefixes to powers:
// (10^(3*<index in powers const>) for kilo, mega, giga, tera, peta, exa, zetta, yotta, ronna, quetta-bytes
// (2^(10*<index in powers const>) for kibi, mebi, gibi, tebi, pebi, exbi, zebi, yobi, "robi", "quibi"-bytes
// Reminder: 2^0 == 10^0 == 1
const powers = ' KMGTPEZYRQ'

// Settings for Utility: truncate
struct Settings {
mut:
	no_create    bool
	io_blocks    bool
	reference    string
	size         string
	size_opt     SizeSettings
	output_files []string
}

enum SizeMode {
	absolute
	add
	subtract
	at_most
	at_least
	round_down
	round_up
}

struct SizeSettings {
	mode SizeMode
mut:
	size u64
}

// if_blank substitutes a blank string with replacement or returns the original
// if it is not blank
fn if_blank(s string, replacement string) string {
	if s != '' {
		return s
	}
	return replacement
}

// get_size returns the file size for path in bytes
fn get_size(path string) u64 {
	attr := os.stat(path) or { app.quit(message: err.msg()) }
	return attr.size
}

// parse_size_operator translates the size op to the SizeMode enum for settings
fn parse_size_operator(op u8) SizeMode {
	return match op {
		`+` { .add }
		`-` { .subtract }
		`<` { .at_most }
		`>` { .at_least }
		`/` { .round_down }
		`%` { .round_up }
		else { .absolute }
	}
}

// calc_target_size takes the input orig_size and modifies it based on the
// selected command options (e.g., returns absolute value or adds or substracts
// from it)
fn calc_target_size(orig_size u64, st SizeSettings, block_size u64) u64 {
	target_size := st.size * block_size
	match st.mode {
		.absolute {
			return target_size
		}
		.at_least {
			return if orig_size < target_size { target_size } else { orig_size }
		}
		.at_most {
			return if orig_size > target_size { target_size } else { orig_size }
		}
		.add {
			return orig_size + target_size
		}
		.subtract {
			return if orig_size < target_size { u64(0) } else { orig_size - target_size }
		}
		.round_down {
			return orig_size - (orig_size % target_size)
		}
		.round_up {
			remainder := orig_size % target_size
			if remainder > 0 {
				return orig_size - remainder + target_size
			}
			return orig_size
		}
	}
}

// parse_size_opt parses the --size parameter into the desired operating mode (op),
// the size and the unit of the size in metric or binary (e.g., kilo or kibibytes)
fn parse_size_opt(opt string) SizeSettings {
	mut re := regex.regex_opt(r'^(?P<op>[+\-<>/%])?(?P<size>\d+)(?P<prefix>[KkMmGgTtPpEeZzYyRrQq])?(?P<unit>(iB)|(B))?$') or {
		app.quit(message: 'regex error')
	}
	start, _ := re.match_string(opt)
	if start < 0 {
		app.quit(message: 'invalid size option: ${opt}')
	}

	// The following asserts should be guaranteed by the regex
	unit := re.get_group_by_name(opt, 'unit')
	assert ['', 'B', 'iB'].contains(unit)
	// KB = Kilobyte (1000 bytes), K or KBi = Kibibyte (1024 bytes), and so on for the
	// mega- and mebibytes and the larger units
	base_unit := if unit == 'B' { 1000 } else { 1024 }

	prefix := if_blank(re.get_group_by_name(opt, 'prefix'), ' ').to_upper()
	assert powers.contains(prefix)

	orig_size := re.get_group_by_name(opt, 'size').u64()
	assert orig_size >= 0

	// Rather than a lengthy match statement, store the powers in ascending order in the powers string and look
	// at the index of the unit to get the power (e.g., gigabyte is 1024^3 and 'G' has index 3 in powers)
	pow := powers.index(prefix) or {
		app.quit(message: 'invalid unit prefix in size option: ${opt}')
	}
	size := orig_size * math.pow(base_unit, pow)
	if size > u64(size) {
		app.quit(message: 'size ${size} too large for 64-bit integer')
	}

	op := if_blank(re.get_group_by_name(opt, 'op'), ' ')
	assert op.len == 1

	// Can't round to multiples of zero
	if (op == '/' || op == '%') && size == 0 {
		app.quit(message: 'division by zero')
	}

	return SizeSettings{
		mode: parse_size_operator(op[0])
		size: u64(size)
	}
}

// args creates the util's settings from the command line options
fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	st.no_create = fp.bool('no-create', `c`, false, 'do not create any files')
	st.io_blocks = fp.bool('io-blocks', `o`, false, 'treat SIZE as number of IO blocks instead of bytes')
	st.reference = fp.string('reference', `r`, '', 'base size on RFILE')
	st.size = fp.string('size', `s`, '', 'set or adjust the file size by SIZE bytes')
	st.output_files = fp.remaining_parameters()

	if st.reference == '' && st.size == '' {
		app.quit(message: 'you must specify either --size or --reference')
	}

	if st.output_files.len < 1 {
		app.quit(message: 'missing file operand')
	}

	if st.io_blocks {
		if st.size == '' {
			app.quit(message: '--io-blocks was specified but --size was not')
		}
	}

	if st.size != '' {
		st.size_opt = parse_size_opt(st.size)
	}

	if st.reference != '' {
		if st.size != '' && st.size_opt.mode == .absolute {
			app.quit(message: 'you must specify a relative ‘--size’ with ‘--reference’')
		}
	}

	return st
}

// truncate does the actual work of creating a file if non exists and calling os.truncate()
// to get it to the desired size
fn truncate(settings Settings) {
	for fname in settings.output_files {
		if settings.reference != '' {
			if !os.exists(fname) && !settings.no_create {
				mut f := os.create(fname) or { app.quit(message: "unable to create '${fname}'") }
				f.close()
			}
			if os.exists(fname) {
				block_size := if settings.io_blocks { get_block_size(fname) or {
						default_block_size} } else { 1 }
				size := calc_target_size(get_size(settings.reference), settings.size_opt,
					block_size)
				os.truncate(fname, size) or { app.quit(message: err.msg()) }
			}
		} else {
			if !os.exists(fname) && !settings.no_create {
				mut f := os.create(fname) or { app.quit(message: "unable to create '${fname}'") }
				f.close()
			}
			// If --no-create is set, nothing is done but no error is generated
			// This is behavior from the original GNU coreutil.
			if os.exists(fname) {
				block_size := if settings.io_blocks { get_block_size(fname) or {
						default_block_size} } else { 1 }
				size := calc_target_size(get_size(fname), settings.size_opt, block_size)
				os.truncate(fname, size) or { app.quit(message: err.msg()) }
			}
		}
	}
}

fn main() {
	truncate(args())
}
