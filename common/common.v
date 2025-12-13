module common

import flag
import os

pub const version = '0.0.1'
pub const err_programming_error = 0x7c
pub const err_not_implemented = 0x7d
pub const err_platform_not_supported = 0x7F

pub struct CoreutilInfo {
pub:
	name        string
	description string
	help        string
}

pub struct CoreutilExitDetail {
pub:
	message string
pub mut:
	show_help_advice bool // defaults to false
	return_code      int = 1
}

// coreutils_version returns formatted coreutils tool version
pub fn coreutils_version() string {
	return '(V coreutils) ${version}'
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
@[noreturn]
pub fn exit_on_errors(errors int) {
	if errors != 0 {
		exit(1)
	}
	exit(0)
}

// exit_with_error_message will exit with error code 1,
// showing the passed error message, and directing the
// user to use --help
@[noreturn]
pub fn exit_with_error_message(tool_name string, error string) {
	if error.len > 0 {
		eprintln('${tool_name}: ${error}')
	}
	eprintln("Try '${tool_name} --help' for more information.")
	exit(1)
}

// A common way to exit with a custom error code (default: 1)
// and the ability to direct the user to help (default: false)
// to make it easier to match the output of the GNU coreutils
@[noreturn]
pub fn (app CoreutilInfo) quit(detail CoreutilExitDetail) {
	eprintln('${app.name}: ${detail.message}')
	if detail.show_help_advice {
		eprintln("Try '${app.name} --help' for more information.")
	}
	exit(detail.return_code)
}

// strip_error_code_from_msg strips the final semicolon and code
// ("<msg>; code: <code>") away from a POSIX and Win32 error to make
// it match what GNU coreutils return
pub fn strip_error_code_from_msg(msg string) string {
	j := msg.last_index('; code: ') or { -1 }
	if j > 0 {
		return msg[0..j]
	} else {
		return msg
	}
}

pub fn (app CoreutilInfo) eprintln(message string) {
	eprintln('${app.name}: ${strip_error_code_from_msg(message)}')
}

pub fn (app CoreutilInfo) eprintln_posix(message string) {
	app.eprintln('${message}: ${os.error_posix()}')
}

// flag_parser returns a flag.FlagParser, with the common
// options already set, reducing the boilerplate code in
// each individual utility.
pub fn (app CoreutilInfo) make_flag_parser(args []string) &flag.FlagParser {
	mut fp := flag.new_flag_parser(args)
	fp.version(coreutils_version())
	if app.help != '' {
		fp.footer(app.help)
	}
	fp.footer(coreutils_footer())
	fp.skip_executable()
	fp.application(app.name)
	fp.description(app.description)
	return fp
}

@[inline]
pub fn eol() string {
	$if windows {
		// WinOS => CRLF
		return '\r\n'
	}
	// POSIX => LF
	return '\n'
}
