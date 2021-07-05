module main

import flag
import os

const (
	app_name     = 'yes'
	app_version  = 'v0.0.1'
)

fn yes() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application(app_name)
	fp.version(app_version)
	fp.description('')
	fp.skip_executable()
	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')

	if help {
		println(fp.usage())
		exit(0)
	}

	if version {
		println('$app_name $app_version')
		exit(0)
	}

	additional_args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		exit(1)
	}

	mut str := 'y'

	if additional_args.len > 1 {
		str = additional_args.join(' ')
	}

	for {
		println(str)
	}
}

fn main() {
	yes()
}

