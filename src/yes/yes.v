module main

import common
import os

const (
	app_name = 'yes'
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

	for {
		println(str)
	}
}

fn main() {
	yes()
}
