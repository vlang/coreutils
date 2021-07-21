import os
import common

const (
	name = 'mv'
)

fn target_not_dir(path string) string {
	return "target '$path' is not a directory"
}

pub fn run_mv(args []string) {
	mv, sources, dest := setup_mv_command(args) or { common.exit_with_error_message(name, err.msg) }
	println(sources)
	println(dest)
	if sources.len > 1 && !os.is_dir(dest) {
		common.exit_with_error_message(name, target_not_dir(dest))
	}
	for source in sources {
		mv.run(source, dest)
	}
	// mv.run(sources,dest)
}

fn setup_mv_command(args []string) ?(MvCommand, []string, string) {
	mut fp := common.flag_parser(args)
	fp.application('mv')
	fp.limit_free_args_to_at_least(1)

	force := fp.bool('force', `f`, false, 'force')
	interactive := fp.bool('interactive', `i`, false, 'interactive')
	no_clobber := fp.bool('no-clobber', `n`, false, 'no-clobber')
	update := fp.bool('update', `u`, false, 'update')
	verbose := fp.bool('verbose', `v`, false, 'verbose')
	target_directory := fp.string('target-directory', `t`, '', 'target-directory')
	no_target_directory := fp.bool('no-target-directory', `T`, false, 'no-target-directory')

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('rm $common.coreutils_version()')
	}

	options := fp.finalize() or { common.exit_with_error_message(name, 'error') }
	len_options := options.len
	if target_directory != '' && len_options < 2 {
		common.exit_with_error_message(name, 'error')
	}
	sources, dest := if target_directory != '' {
		options, target_directory
	} else {
		options[0..len_options - 1], options[len_options - 1]
	}

	return MvCommand{
		force: force
		interactive: interactive
		no_clobber: no_clobber
		update: update
		verbose: verbose
		target_directory: target_directory
		no_target_directory: no_target_directory
	}, sources, dest
}

// Print messages and exit
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}
