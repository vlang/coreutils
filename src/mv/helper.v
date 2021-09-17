import os
import common

const (
	name            = 'mv'
	interactive_yes = ['y']
	combine_t_no_t  = 'cannot combine --target-directory (-t) and --no-target-directory (-T)'
)

fn prompt_file(path string) string {
	return "overwrite '$path'? "
}

fn target_not_dir(path string) string {
	return "target '$path' is not a directory"
}

fn renamed(src string, dst string) string {
	return "renamed '$src' -> '$dst'"
}

fn missing_dest(path string) string {
	return "missing destination file operand after '$path'"
}

fn no_dir_is_dir(path string) string {
	return "cannot overwrite directory '$path' with non-directory"
}

fn not_exist(path string) string {
	return "$name: cannot stat '$path': No such file or directory"
}

fn extra_operand(operand string) string {
	return "extra operand '$operand'"
}

fn valid_yes(input string) bool {
	mut is_yes := false
	low_input := input.to_lower()
	for yes in interactive_yes {
		is_yes = is_yes || low_input.starts_with(yes)
	}
	return is_yes
}

// Take user confirmation and check if it is considered yes
fn int_yes(prompt string) bool {
	return valid_yes(os.input(prompt))
}

pub fn run_mv(args []string) {
	mv, sources, dest := setup_mv_command(args) or { common.exit_with_error_message(name, err.msg) }
	if sources.len > 1 && !os.is_dir(dest) {
		common.exit_with_error_message(name, target_not_dir(dest))
	}
	for source in sources {
		mv.run(source, dest)
	}
}

fn setup_mv_command(args []string) ?(MvCommand, []string, string) {
	mut fp := common.flag_parser(args)
	fp.application('mv')
	fp.limit_free_args_to_at_least(1) ?

	force := fp.bool('force', `f`, false, 'ignore interactive and no-clobber')
	interactive := fp.bool('interactive', `i`, false, 'ask for each overwrite')
	no_clobber := fp.bool('no-clobber', `n`, false, 'do not overwrite')
	update := fp.bool('update', `u`, false, 'update')
	verbose := fp.bool('verbose', `v`, false, 'print each rename')
	target_directory := fp.string('target-directory', `t`, '', 'target-directory')
	no_target_directory := fp.bool('no-target-directory', `T`, false, 'no-target-directory')

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('$name $common.coreutils_version()')
	}

	options := fp.finalize() or { common.exit_with_error_message(name, 'error') }
	overwrite := if force {
		OverwriteMode.force
	} else if no_clobber {
		OverwriteMode.no_clobber
	} else if interactive {
		OverwriteMode.interactive
	} else {
		OverwriteMode.force
	}
	len_options := options.len
	if target_directory != '' {
		if no_target_directory {
			common.exit_with_error_message(name, combine_t_no_t)
		}
		if !os.exists(target_directory) {
			common.exit_with_error_message(name, not_exist(target_directory))
		}
		if !os.is_dir(target_directory) {
			common.exit_with_error_message(name, target_not_dir(target_directory))
		}
	} else {
		if len_options < 2 {
			common.exit_with_error_message(name, missing_dest(options[0]))
		}
		if no_target_directory {
			if len_options > 2 {
				common.exit_with_error_message(name, extra_operand(options[2]))
			}
			if os.is_dir(options[1]) {
				common.exit_with_error_message(name, no_dir_is_dir(options[1]))
			}
		}
	}
	sources, dest := if target_directory != '' {
		options, target_directory
	} else {
		options[0..len_options - 1], options[len_options - 1]
	}

	return MvCommand{
		overwrite: overwrite
		update: update
		verbose: verbose
		target_directory: target_directory
		no_target_directory: no_target_directory
	}, sources, dest
}

// Print messages and exit with error
[noreturn]
fn error_exit(messages ...string) {
	for message in messages {
		eprintln(message)
	}
	exit(1)
}

// Print messages and exit
[noreturn]
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}
