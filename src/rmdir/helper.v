import common

const (
	name              = 'rmdir'
	valid_interactive = [
		['never', 'no', 'none'],
		['once'],
		['always', 'yes'],
	]
)

fn success_exit(msg string) {
	println(msg)
	exit(0)
}

fn setup_rmdir_command(args []string) ?(RmdirCommand, []string) {
	mut fp := common.flag_parser(args)
	fp.application('rm')
	fp.limit_free_args_to_at_least(1) ?

	parents := fp.bool('parents', `p`, false, 'parents')
	verbose := fp.bool('verbose', `v`, false, 'verbose')
	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')

	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('rm $common.coreutils_version()')
	}
	rmdir := RmdirCommand{verbose, parents}

	dirs := fp.finalize() ?

	return rmdir, dirs
}

fn run_rmdir(args []string) {
	rmdir, dirs := setup_rmdir_command(args) or { common.exit_with_error_message(name, err.msg) }
	for dir in dirs {
		rmdir.remove_dir(dir)
	}
}
