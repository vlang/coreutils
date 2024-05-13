module main

import common
import os

const app_name = 'touch'

struct TouchCommand {
	access_time_only bool
	no_create        bool
	file_args        []string
}

// Print messages and exit
@[noreturn]
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}

fn touch(cmd TouchCommand) {
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.limit_free_args_to_at_least(1)!
	fp.usage_example('Usage: [OPTION]... FILE...\n')
	fp.description('Update the access and modification times of each FILE to the current time.')
	fp.description('')
	fp.description('A FILE argument that does not exist is created empty, unless -c or -h')
	fp.description('is supplied.')
	fp.description('')
	fp.description('A FILE argument string of - is handled specially and causes touch to')
	fp.description('change the times of the file associated with standard output.')

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

	file_args := fp.finalize() or { common.exit_with_error_message(app_name, err.msg()) }


	cmd := TouchCommand{
		access_time_only: access_time_only
		no_create: no_create
		file_args: file_args
	}

	touch(cmd)
}
