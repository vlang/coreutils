module main

import os
import common

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('basename')
	fp.description('Strip directory and suffix from a file name')
	fp.limit_free_args_to_at_least(1) ?
	mut is_multi := fp.bool('multiple', `a`, false, 'support multiple args as NAME')
	mut suffix := ''
	if _suffix := fp.string_opt('suffix', `s`, 'remove a trailing SUFFIX; implies -a') {
		is_multi = true
		suffix = _suffix
	}
	is_zero := fp.bool('zero', `z`, false, '')
	fp.allow_unknown_args()
	args := fp.remaining_parameters()
	if is_multi {
		for file in args {
			basename(file, suffix, is_zero)
		}
	} else {
		match args.len {
			1 {
				basename(args[0], '', is_zero)
			}
			2 {
				basename(args[0], args[1], is_zero)
			}
			else {
				common.exit_with_error_message(os.args[0], 'extra args `${args[2]}`')
			}
		}
	}
}

fn basename(name string, suffix string, is_zero bool) {
	mut out := ''
	if name != '' {
		mut i := name.len - 1
		for i >= 0 {
			if name[i] != `/` {
				break
			}
			i--
		}
		name_noslash := name[0..i + 1]
		if name_noslash == '' {
			out = '/'
		} else {
			if idx := name_noslash.last_index('/') {
				out = name_noslash[idx + 1..]
			} else {
				out = name_noslash
			}
			if out != suffix {
				out = out.trim_suffix(suffix)
			}
		}
	}
	if is_zero {
		print(out)
		print(`\0`)
	} else {
		println(out)
	}
}
