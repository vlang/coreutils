module main

import os
import common

fn main() {
	mut fp := common.flag_parser(os.args)

	fp.application('dirname')
	fp.description('strip the last file name component')

	is_zero := fp.bool('zero', `z`, false, '')

	fp.allow_unknown_args()

	args := fp.remaining_parameters()

	exit_success := 0

	// Empty args == '.'
	if args.len == 0 {
		print_out('.', is_zero)
		exit(exit_success)
	}

	for arg in args {
		d := dirname(arg)
		print_out(d, is_zero)
	}
	// EXIT_SUCCESS
	exit(exit_success)
}

fn print_out(out string, is_zero bool) {
	if is_zero {
		print('${out}\0')
	} else {
		println(out)
	}
}

fn last_component(name string) int {
	mut base := 0
	mut last_slash := false
	slash := if os.user_os() == 'windows' { u8(92) } else { u8(47) }

	for ch in name {
		if ch == slash {
			base++
		} else {
			break
		}
	}

	for i := base; i < name.len; i++ {
		if name[i] == slash {
			last_slash = true
		} else if last_slash {
			base = i
			last_slash = false
		}
	}

	if last_slash {
		base--
	}

	return base
}

fn dirname(path string) string {
	basename_index := last_component(path)
	return os.dir(path[..basename_index])
}
