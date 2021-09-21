module main

import common
import os

const (
	app_name = 'true'
)

fn true_fn() ? {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('Exit with a status code indicating success.')
	fp.limit_free_args(0, 0) ?
	fp.finalize() or {}

	exit(0)
}

fn main() {
	true_fn() ?
}
