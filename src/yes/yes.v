module yes

import common
import os

const app_name = 'yes'
const buf_size = 8192

// run is the entry point shared by the standalone binary and the multicall
// binary, so both dispatch through the same code.
//
// The write loop never terminates, so the return at the end is unreachable; it
// is there because the multicall needs an int status from every tool.
pub fn run(args []string) int {
	mut fp := common.flag_parser(args)
	fp.application(app_name)
	fp.description('')

	additional_args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return 1
	}

	mut expletive := 'y'

	if additional_args.len > 0 {
		expletive = additional_args.join(' ')
	}
	expletive += '\n'

	mut yes_buf := unsafe { malloc(buf_size) }
	mut buf_used := 0

	for buf_used + expletive.len <= buf_size {
		unsafe {
			vmemcpy(yes_buf + buf_used, expletive.str, expletive.len)
		}
		buf_used += expletive.len
	}

	mut out := os.stdout()
	unsafe {
		for {
			out.write_ptr(yes_buf, buf_used)
		}
	}
	return 0
}
