module main

import common
import os

const (
	app_name = 'false'
)

fn false_fn() ? {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('Exit with a status code indicating failure.')
	fp.limit_free_args(0, 0) ?
	fp.finalize() or {}

	exit(1)
}

fn main() {
	false_fn() ?
}
