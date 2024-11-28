import os
import common

const name = 'mkfifo'
const default_mode = u32(0o600)

struct Options {
	mode u32
}

fn mkfifo_cmd(list []string, opts &Options) {
	for path in list {
		ret := mkfifo(path, opts.mode)
		if ret != 0 {
			common.exit_with_error_message(name, os.posix_get_error_msg(ret))
		}
	}
}

fn run_mkfifo(args []string) {
	mut fp := common.flag_parser(args)
	fp.application(name)
	fp.usage_example('[OPTION]... NAME...')
	fp.description('Create named pipes (FIFOs) with the given NAMEs.')
	fp.description('Mandatory arguments to long options are mandatory for short options too.')

	mut opts := Options{
		mode: u32(fp.int('mode', `m`, int(default_mode), 'set file permission bits to MODE, not a=rw - umask'))
	}

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	if help {
		println(fp.usage())
		exit(0)
	}
	if version {
		println('${name} ${common.coreutils_version()}')
		exit(0)
	}

	file_args := fp.finalize() or { common.exit_with_error_message(name, err.msg()) }
	if file_args.len == 0 {
		common.exit_with_error_message(name, 'missing operand')
	}

	mkfifo_cmd(file_args, &opts)
}

fn main() {
	run_mkfifo(os.args)
	exit(0)
}
