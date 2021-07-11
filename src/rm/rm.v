import os
import flag
import common

//** Constants and simple string substitution functions **
const (
	name                = 'rm'
	interactive_yes     = ['y']
	invalid_interactive = 'Invalid for interactive. Use either of [never, no, none], [once], [always, yes]'
	valid_interactive   = [
		['never', 'no', 'none'],
		['once'],
		['', 'always', 'yes'],
	]
)

fn rem(path string) string {
	return "removed '$path'"
}

fn prompt_file(path string) string {
	if os.file_size(path) == 0 {
		return prompt_file_empty(path)
	}
	return prompt_file_nonempty(path)
}

fn err_is_dir(path string) string {
	return "cannot remove '$path': Is a directory"
}

fn err_is_dir_empty(path string) string {
	return "cannot remove '$path': Directory not empty"
}

fn prompt_descend(path string) string {
	return "rm: descend into directory '$path'? "
}

fn prompt_file_nonempty(path string) string {
	return "rm: remove regular file '$path'? "
}

fn prompt_file_empty(path string) string {
	return "rm: remove regular empty file '$path'? "
}

fn prompt_dir(path string) string {
	return "rm: remove directory '$path? "
}

fn rem_args(len int) string {
	arg := if len == 1 { 'argument' } else { 'arguments' }
	return 'Remove $len $arg? '
}

fn rem_recurse(len int) string {
	arg := if len == 1 { 'argument' } else { 'arguments' }
	return 'rm: remove $len $arg recursively? '
}

//** End of constants and string substitution functions **

//** RmCommand struct to hold values **
struct RmCommand {
	recursive   bool
	dir         bool
	interactive bool
	verbose     bool
	force       bool
	less_int    bool
}

fn (r RmCommand) rm_dir(path string) {
	if !r.recursive {
		if !r.dir {
			error_message(name, err_is_dir(path))
			return
		}

		// --dir flag set, so remove if empty dir
		if !os.is_dir_empty(path) {
			error_message(name, err_is_dir_empty(path))
			return
		}
	}
	// Can just delete all
	if !r.interactive && !r.verbose {
		os.rmdir_all(path) or { eprintln(err.str()) }
	}
	// Need to go through recursively to print/interact
	r.rm_dir_verbose_inter(path)
}

fn int_yes(prompt string) bool {
	mut is_yes := false
	for yes in interactive_yes {
		is_yes = is_yes || os.input(prompt).to_lower().contains(yes)
	}
	return is_yes
}

fn (r RmCommand) rm_dir_verbose_inter(path string) bool {
	if !r.int_yes(prompt_descend(path)) {
		return true
	}

	items := os.ls(path) or {
		eprintln(err.str())
		return false
	}
	mut ok := true
	for item in items {
		curr_path := os.join_path(path, item)
		if os.is_dir(curr_path) {
			ok = ok && r.rm_dir_verbose_inter(curr_path)
			continue
		}

		if !r.int_yes(prompt_file(curr_path)) {
			continue
		}

		os.rm(curr_path) or {
			eprintln(err.str())
			return false
		}
		if r.verbose {
			println(rem(curr_path))
		}
	}

	if r.int_yes(prompt_dir(path)) {
		os.rmdir(path) or {
			eprintln(err.str())
			return false
		}
		if r.verbose {
			println(rem(path))
		}
	}

	return ok
}

fn (r RmCommand) int_yes(prompt string) bool {
	return !r.interactive || int_yes(prompt)
}

fn (r RmCommand) rm_path(path string) {
	if os.is_dir(path) {
		r.rm_dir(path)
		return
	}
	if !r.interactive || r.force || r.int_yes(prompt_file(path)) {
		os.rm(path) or { error_message(name, err.msg) }
		if r.verbose {
			println(rem(path))
		}
	}
}

fn error_message(tool_name string, error string) {
	if error.len > 0 {
		eprintln('$tool_name: $error')
	}
}

fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}

enum Interactive {
	no
	once
	yes
}

fn check_interactive(interactive string) ?Interactive {
	for i in int(Interactive.no) .. int(Interactive.yes) + 1 {
		if interactive in valid_interactive[i] {
			return Interactive(i)
		}
	}
	return error(invalid_interactive)
}

fn setup_rm_command(mut fp flag.FlagParser) ?(RmCommand, []string) {
	fp.application('rm')
	fp.limit_free_args_to_at_least(1)
	mut recursive := fp.bool('', `R`, false, '')
	recursive = recursive || fp.bool('recursive', `r`, false, 'recursive')
	dir := fp.bool('dir', `d`, false, 'dir')
	force := fp.bool('force', `f`, false, 'force')
	interactive := fp.string('interactive', 0, '', 'interactive')
	mut int_type := Interactive.no
	if interactive != '' {
		int_type = check_interactive(interactive) ?
	} else {
		int_type = Interactive.no
	}
	interactive_all := fp.bool('', `i`, false, 'interactive always') || (int_type == .yes)
	less_int := fp.bool('', `I`, false, 'interactive once') || (int_type == .once)

	verbose := fp.bool('verbose', `v`, false, 'verbose')

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')

	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('rm $common.coreutils_version()')
	}
	rm := RmCommand{
		recursive: recursive
		dir: dir
		interactive: interactive_all
		less_int: less_int
		verbose: verbose
		force: force
	}
	files := fp.finalize() ?
	return rm, files
}

fn main() {
	mut fp := common.flag_parser(os.args)

	rm, files := setup_rm_command(mut fp) or {
		common.exit_with_error_message(name, err.msg)
		return
	}

	if rm.less_int && !rm.interactive {
		ans := if files.len > 3 {
			int_yes(rem_args(files.len))
		} else if rm.recursive {
			int_yes(rem_recurse(files.len))
		} else {
			true
		}

		if !ans {
			success_exit()
		}
	}
	for file in files {
		rm.rm_path(file)
	}
	success_exit()
}
