import os
import common

struct MvCommand {
	force               bool
	interactive         bool
	no_clobber          bool
	update              bool
	verbose             bool
	target_directory    string
	no_target_directory bool
}

fn (m MvCommand) run(source string, dest string) {
	if m.verbose || (!m.force && (m.interactive || m.no_clobber)) {
		// m.mv(source,dest)
	}
	os.mv(source, dest) or { common.exit_with_error_message(name, err.msg) }
	// if os.is_dir()
	// println(name)
}
