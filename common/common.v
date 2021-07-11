module common

import flag

pub const version = '0.0.1'

// coreutils_version returns formatted coreutils tool version
pub fn coreutils_version() string {
	return '(V coreutils) $common.version'
}

// coreutils_footer returns a formatted coreutils footer
pub fn coreutils_footer() string {
	return '\nHelp us make V Coreutils better, by contributing your suggestions,\nideas and pull requests in https://github.com/vlang/coreutils'
}

// flag_parser returns a flag.FlagParser, with the common
// options already set, reducing the boilerplate code in
// each individual utility.
pub fn flag_parser(args []string) &flag.FlagParser {
	mut fp := flag.new_flag_parser(args)
	fp.version(coreutils_version())
	fp.footer(coreutils_footer())
	fp.skip_executable()
	return fp
}

// exit_on_errors will exit with a code of either 0 or 1,
// depending on the passed `errors` counter.
[noreturn]
pub fn exit_on_errors(errors int) {
	if errors != 0 {
		exit(1)
	}
	exit(0)
}

// exit_with_error_message will exit with error code 1,
// showing the passed error message, and directing the
// user to use --help
[noreturn]
pub fn exit_with_error_message(tool_name string, error string) {
	if error.len > 0 {
		eprintln('$tool_name: $error')
	}
	eprintln("Try '$tool_name --help' for more information.")
	exit(1)
}
