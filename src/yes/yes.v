module main

import common
import os

const (
	app_name = 'yes'
	buf_size = 8192
)

fn yes() {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('')

	additional_args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		exit(1)
	}

	mut str := 'y'

	if additional_args.len > 0 {
		str = additional_args.join(' ')
	}
	str += '\n'
	expletive := voidptr(&(str.bytes())[0])

	mut yes_buf := unsafe { malloc(buf_size) }
	mut buf_used := 0

	for buf_used + str.len <= buf_size {
		unsafe {
			vmemcpy(yes_buf + buf_used, expletive, str.len)
		}
		buf_used += str.len
	}

	mut out := os.stdout()
	unsafe {
		for {
			out.write_ptr(yes_buf, buf_used)
		}
	}
}

fn main() {
	yes()
}
