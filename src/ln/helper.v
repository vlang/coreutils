import common

const (
	name = 'ln'
)

fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}

fn run_ln(args []string) {
	mut fp := common.flag_parser(args)
	fp.application(name)
	fp.limit_free_args_to_at_least(2) or { common.exit_with_error_message(name, err.msg()) }

	force := fp.bool('', `f`, false, 'Force existing destination pathnames to be removed to allow the link.')
	follow_symbolic := fp.bool('', `L`, false, 'For each source_file operand that names a file of type symbolic link, create a (hard) link to the file referenced by the symbolic link.')
	no_follow_symbolic := fp.bool('', `P`, false, 'For each source_file operand that names a file of type symbolic link, create a (hard) link to the symbolic link itself.')
	symbolic := fp.bool('', `s`, false, 'Create symbolic links instead of hard links. If the −s option is specified, the −L and −P options shall be silently ignored.')

	help := fp.bool('help', 0, false, 'Display this help and exit')
	version := fp.bool('version', 0, false, 'Output version information and exit')

	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('${name} ${common.coreutils_version()}')
	}

	files := fp.finalize() or { common.exit_with_error_message(name, err.msg()) }

	mut ln := Linker{
		force: force
		follow_symbolic: follow_symbolic
		no_follow_symbolic: no_follow_symbolic
		symbolic: symbolic
		target: files.last()
		sources: files[..files.len - 1]
	}
	ln.run()
}
