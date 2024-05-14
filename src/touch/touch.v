module main

import common
import os
import time

const app_name = 'touch'

struct TouchArgs {
	access_time_only bool
	no_create        bool
	path_args        []string
}

// Print messages and exit
@[noreturn]
fn success_exit(message string) {
	println(message)
	exit(0)
}

@[noreturn]
fn error_exit(message string) {
	println(message)
	exit(1)
}

fn touch(args TouchArgs) int {
	now := int(time.utc().unix())

	for path in args.path_args {
		if os.exists(path) {
			os.utime(path, now, now) or { error_exit('unable to modify ${path}') }	
		}
		else {
			mut file := os.create(path) or { error_exit('unable to create ${path}') }
			file.close()
		}
	}
	return 0
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.limit_free_args_to_at_least(1)!
	fp.usage_example('[OPTION]... FILE...')
	fp.description('\n\nUpdate the access and modification times of each FILE to the current time.')
	fp.description('\nA FILE argument that does not exist is created empty, unless -c or -h is supplied')
	fp.description('\nA FILE argument string of - is handled specially and causes touch to change the\ntimes of the file associated with standard output.')

	access_time_only := fp.bool('', `a`, false, 'change only the access time')
	no_create := fp.bool('no-create', `c`, false, 'do not create any files')

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')

	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('${app_name} ${common.coreutils_version()}')
	}

	path_args := fp.finalize() or { common.exit_with_error_message(app_name, err.msg()) }

	args := TouchArgs{
		access_time_only: access_time_only
		no_create: no_create
		path_args: path_args
	}

	touch(args)
}
