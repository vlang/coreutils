// module rmutil
import os
import common

// Important constants
const (
	name                = 'rm'
	interactive_yes     = ['y']
	invalid_interactive = 'Invalid for interactive. Use either of [never, no, none], [once], [always, yes]'
	valid_interactive   = [
		['never', 'no', 'none'],
		['once'],
		['always', 'yes'],
	]
)

// Enum for interactive level
enum Interactive {
	no
	once
	yes
}

// String substitution functions for errors and prompts
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

fn err_not_exist(path string) string {
	return "failed to remove '$path: No such file or directory"
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

// End of string substitution functions

// Print error with tool name behind it
fn error_message(tool_name string, error string) {
	if error.len > 0 {
		eprintln('$tool_name: $error')
	}
}

// Print messages and exit
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
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

// Check if value provided for interactive option is valid
fn check_interactive(interactive string) ?Interactive {
	for i in int(Interactive.no) .. int(Interactive.yes) + 1 {
		if interactive in valid_interactive[i] {
			return Interactive(i)
		}
	}
	return error(invalid_interactive)
}

// Parse flags, create command struct and get all options (files)
fn setup_rm_command(args []string) ?(RmCommand, []string) {
	mut fp := common.flag_parser(args)
	fp.application('rm')
	fp.limit_free_args_to_at_least(1)

	dir := fp.bool('dir', `d`, false, 'dir')
	force := fp.bool('force', `f`, false, 'force')
	verbose := fp.bool('verbose', `v`, false, 'verbose')
	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')

	mut recursive := fp.bool('', `R`, false, '')
	recursive = recursive || fp.bool('recursive', `r`, false, 'recursive')

	interactive_str := fp.string('interactive', 0, '', 'interactive')
	mut int_type := Interactive.no
	if interactive_str != '' {
		int_type = check_interactive(interactive_str) ?
	} else {
		int_type = Interactive.no
	}

	interactive := fp.bool('', `i`, false, 'interactive always') || (int_type == .yes)
	less_int := fp.bool('', `I`, false, 'interactive once') || (int_type == .once)

	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('rm $common.coreutils_version()')
	}

	rm := RmCommand{recursive, dir, interactive, verbose, force, less_int}

	files := fp.finalize() ?

	// println(rm)
	return rm, files
}

// Entry point for all logic. Must be called from main
pub fn run_rm(args []string) {
	// Create command struct and accept flags and files
	rm, files := setup_rm_command(args) or { common.exit_with_error_message(name, err.msg) }

	// Take confirmation if necessary
	if rm.confirm_int_once(files.len) {
		for file in files {
			rm.rm_path(file)
		}
	}
}
