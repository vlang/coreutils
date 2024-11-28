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
	reference   string
	no_ref      bool
	path_args   []string
}

fn main() {
	touch(os.args)
}

fn touch(args []string) {
	mut fp := common.flag_parser(args)
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
	date_arg := fp.string('date_time', `d`, '', 'Use specified date. format=ISO-8601')
	fp.bool('', `f`, false, 'ignored (for compatibility with BSD)')
	no_ref := fp.bool('no-reference', `h`, false, 'affect each symbolic link instead of any referenced file')
	mod_only := fp.bool('', `m`, false, 'change modifcation time only')
	reference := fp.string('reference', `r`, '', 'use times from file <string>')
	time_arg := fp.string('time', `t`, '', 'same as -d')

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
		common.exit_with_error_message(app_name, 'FILE... option not specified.')
	}

	touch_args := TouchArgs{
		access_only: access_only
		mod_only:    mod_only
		no_create:   no_create
		time_arg:    time_arg
		date_arg:    date_arg
		reference:   reference
		no_ref:      no_ref
		path_args:   path_args
	}

	process_touch(touch_args)
}

fn process_touch(args TouchArgs) {
	atime, mtime := get_date_time(args)

	for path_arg in args.path_args {
		if !os.exists(path_arg) {
			if args.no_create {
				continue
			}
			create_file(path_arg)
		}

		path := if args.no_ref { path_arg } else { os.real_path(path_arg) }

		lstat := os.lstat(path) or {
			common.exit_with_error_message(app_name, 'unable to query ${path}')
		}

		acc := if args.mod_only && !args.access_only { int(lstat.atime) } else { atime }
		mod := if args.access_only && !args.mod_only { int(lstat.mtime) } else { mtime }

		lutime(path, acc, mod) or {
			common.exit_with_error_message(app_name, 'unable to change times for ${path}')
		}
	}
}

fn get_date_time(args TouchArgs) (int, int) {
	if args.date_arg.len > 0 && args.time_arg.len > 0 {
		common.exit_with_error_message(app_name, '-d or -t but not both')
	}

	if (args.date_arg.len > 0 || args.time_arg.len > 0) && args.reference.len > 0 {
		common.exit_with_error_message(app_name, 'reference file or date/time but not both')
	}

	dt := if args.date_arg.len > 0 { args.date_arg } else { args.time_arg }

	if dt.len > 0 {
		date := time.parse_iso8601(dt) or {
			common.exit_with_error_message(app_name, 'unable to parse date ${dt}')
		}
		return int(date.unix()), int(date.unix())
	}

	if args.reference.len > 0 {
		// os.stat follows links
		stat := os.stat(args.reference) or {
			common.exit_with_error_message(app_name, 'unable to find reference file ${args.reference}')
		}

		return int(stat.atime), int(stat.mtime)
	}

	return int(time.utc().unix()), int(time.utc().unix())
}

fn create_file(path string) {
	mut file := os.create(path) or {
		common.exit_with_error_message(app_name, 'unable to create ${path}')
	}
	file.close()
}

@[noreturn]
fn success_exit(message string) {
	println(message)
	exit(0)
}
