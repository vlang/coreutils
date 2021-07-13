module mvutil

import common

const (
	name = 'mv'
)

pub fn run_mv(args []string) {
	mv := setup_mv_command(args) or { common.exit_with_error_message(name,err.msg) }
}

fn setup_mv_command(args []string) ?MvCommand {
	mut fp:= common.flag_parser(args)
	fp.application('mv')

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('rm $common.coreutils_version()')
	}
	return MvCommand{}
}

// Print messages and exit
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}
