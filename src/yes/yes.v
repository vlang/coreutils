module main

import flag
import os

const (
	app_name    = 'yes'
	app_version = 'v0.0.1'
)

fn yes() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application(app_name)
	fp.version(app_version)
	fp.description('')
	fp.skip_executable()

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
