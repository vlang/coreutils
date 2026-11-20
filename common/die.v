module common

// die reports a GNU-style failure and exits. The status is passed in because
// the tools disagree about it: chown uses 1 for an operand problem while chroot
// and runcon use 125 for anything they could not do themselves, and 127 for a
// command that could not be found.
@[noreturn]
pub fn die(tool_name string, message string, code int) {
	if message.len > 0 {
		eprintln('${tool_name}: ${message}')
	}
	exit(code)
}

// fail_with_help reports a usage failure and exits 1, which is what GNU does
// for a malformed command line regardless of the tool.
@[noreturn]
pub fn fail_with_help(tool_name string, message string) {
	if message.len > 0 {
		eprintln('${tool_name}: ${message}')
	}
	eprintln("Try '${tool_name} --help' for more information.")
	exit(1)
}
