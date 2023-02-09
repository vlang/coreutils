module main

import os
import common

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('dirname')
	fp.description('strip non-directory suffix from file name')

	is_zero := fp.bool('zero', `z`, false, '')
	fp.allow_unknown_args()
	args := fp.remaining_parameters()

	// Empty args == '.'
	if args.len == 0 {
		print_out('.', is_zero)
	}

	for arg in args {
		d := dirname(arg)
		print_out(d, is_zero)
	}
}

fn print_out(out string, is_zero bool) {
	if is_zero {
		print('${out}\0')
	} else {
		println(out)
	}
}

fn dirname(path string) string {
	// Empty strings == '.'
	if path.len == 0 {
		return '.'
	}

	mut len := path.len - 1
	slash := u8(47)

	// strip any trailing slashes; 47 == '/'
	for len > 0 && path[len] == slash {
		len--
	}

	// find start of directory
	for len > 0 && path[len] != slash {
		len--
	}

	// leading slash or no slashes at all
	if len == 0 {
		return if path[len] == slash { '/' } else { '.' }
	} else {
		// move past separating slashes
		for len > 0 && path[len] == slash {
			len--
		}
	}

	len++

	return path[..len]
}
