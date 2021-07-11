module main

import flag
import os

const (
	app_name    = 'false'
	app_version = 'v0.0.1'
)

fn false_fn() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application(app_name)
	fp.version(app_version)
	fp.description('Exit with a status code indicating failure.')
	fp.limit_free_args(0, 0)
	fp.skip_executable()
	fp.finalize() or {}

	exit(1)
}

fn main() {
	false_fn()
}
