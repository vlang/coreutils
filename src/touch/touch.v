module main

import common
import os
import time

const app_name = 'touch'

struct TouchArgs {
	access_only bool
	mod_only    bool
	no_create   bool
	time_arg    string
	date_arg    string
	path_args   []string
}

// Print messages and exit
@[noreturn]
fn success_exit(message string) {
	println(message)
	exit(0)
}

fn get_date_time(args TouchArgs) (int, int) {
	now := int(time.utc().unix())
	mut acc := now
	mut mod := now

	if args.date_arg.len > 0 {
		date := time.parse_iso8601(args.date_arg) or {
			common.exit_with_error_message(app_name, 'unable to parse date ${args.date_arg}')
		}
		unix := int(date.unix())
		acc = unix
		mod = unix
	}

	return acc, mod
}

fn touch(args TouchArgs) int {
	mut acc, mut mod := get_date_time(args)

	for path in args.path_args {
		if !os.exists(path) {
			if args.no_create {
				continue
			}

			mut file := os.create(path) or {
				common.exit_with_error_message(app_name, 'unable to create ${path}')
			}

			file.close()
		}

		stat := os.lstat(path) or {
			common.exit_with_error_message(app_name, 'unable to query ${path}')
		}

		if args.access_only {
			mod = int(stat.mtime)
		}

		if args.mod_only {
			acc = int(stat.atime)
		}

		os.utime(path, acc, mod) or {
			common.exit_with_error_message(app_name, 'unable to change times for ${path}')
		}
	}

	return 0
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.usage_example('[OPTION]... FILE...')
	fp.description('Change file access and modification times${common.eol()}')
	fp.description('A FILE argument that does not exist is created empty,')
	fp.description('unless -c or -h is supplied${common.eol()}')
	fp.description('The time used can be specified by the -t time OPTION, the')
	fp.description('corresponding time fields of the file referenced by the')
	fp.description('-r ref_file OPTION, or the -d date_time OPTION. If none')
	fp.description('of these are specified, touch uses the current time.')

	access_only := fp.bool('', `a`, false, 'change access time only')
	no_create := fp.bool('no-create', `c`, false, 'do not create any files')
	date_arg := fp.string('date_time', `d`, '', 'Use specified date.')
	mod_only := fp.bool('', `m`, false, 'change modifcation time only')
	time_arg := fp.string('time', `t`, '', 'Use specified time.')

	help := fp.bool('help', 0, false, 'display this help')
	version := fp.bool('version', 0, false, 'display version information')

	if help {
		success_exit(fp.usage())
	}

	if version {
		success_exit('${app_name} ${common.coreutils_version()}')
	}

	path_args := fp.finalize() or { common.exit_with_error_message(app_name, err.msg()) }

	if path_args.len == 0 {
		common.exit_with_error_message(app_name, 'No FILE... option specified')
	}

	args := TouchArgs{
		access_only: access_only
		mod_only: mod_only
		no_create: no_create
		time_arg: time_arg
		date_arg: date_arg
		path_args: path_args
	}

	touch(args)
}
