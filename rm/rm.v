import os
import flag		
/* The following block has been created in this file, but should be extracted to a common module for use by all utils
*/

const (
	version_str = 'V Coreutils 0.0.1'
)

// A default error exit, when code is not important
fn error_exit(errors ...string) {
	error_exit_code(1, ...errors)
}

// Use only if error code is important (some semantic meaning to particular codes)
fn error_exit_code(code int, errors ...string) {
	for error in errors {
		eprintln(error)
	}
	exit(code)
}

// Use if successful exit
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}

/*
** Standard function to perform basic flag parsing an help and version processing
** params: args - string array (should usually be os.args in main function)
** returns: FlagParser object reference, exec name
** logic: Creates a parser with given arguments. Checks if --help or --version flag are present, and prints and exits if yes
*/

fn flags_common(args []string, app_name string, free_args_min int, free_args_max int) (&flag.FlagParser, string) {
	// Flags
	mut fp := flag.new_flag_parser(os.args)
	fp.application(app_name)
	fp.limit_free_args(free_args_min, free_args_max)
	fp.version(version_str) // Preferably take from common version constant, should be updated regularly
	fp.description('Remove files as mentioned')
	exec := fp.args[0]

	// println(exec)

	// --help and --version are standard flags for coreutils programs
	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')

	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit(version_str) // Needs to be modified
	}

	fp.skip_executable()

	return fp, exec
}

// Use if no arguments are taken
fn flags_common_no_args(args []string, app_name string) (&flag.FlagParser, string) {
	return flags_common(args, app_name, 0, 0)
}

/* End of common block
*/

fn rm_recurse(dir string) []string{
	mut files_stack := [dir]
	// println(direct_ls)
	// files_stack << direct_ls
	mut i:=0
	for i < files_stack.len {
		curr_file := files_stack[i]
		direct_ls := os.ls(curr_file) or {[]}
		println('$curr_file: $direct_ls')
		files_stack << direct_ls.map(os.join_path(curr_file,it))
		i++
	}
	println(files_stack)
	mut errors := []string{}
	for j := files_stack.len-1; j >= 0; j-- {
		println(files_stack[j])
		os.rm(files_stack[j]) or {errors << err.str()}
	}
	return errors
}
fn main() {
mut fp, _ := flags_common(os.args, 'rm', 1,flag.max_args_number)
try_help := "Try 'rm --help' for more information"
// empty := fp.bool('file',0, false,'empty')
// println(empty)
recursive := fp.bool('recursive', 0, false, 'recursive')
files := fp.finalize() or { 
	error_exit(err.str(), try_help)
	return
}
// println(files)
mut errors := []string{}
for file in files {
	if os.is_dir(file) {
		if !recursive {
			errors << 'Cannot remove file: Is a directory'
			continue
		}
		os.rmdir_all(file) or {errors << err.str()}
	} else { 
		os.rm(file) or { errors << err.str() } 
	}
}
if errors.len > 0 {error_exit(...errors)}
success_exit()
}
