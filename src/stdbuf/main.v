import common
import common.stdbuf
import os

fn main() {
	set := stdbuf.parse_args(os.args[1..])
	if set.command.len == 0 {
		common.die(app_name, 'missing operand', 125)
	}

	// The buffer modes are collected but not applied: applying them means
	// preloading a compiled shared library that overrides setvbuf in the
	// child, and building that library at run time is not something this
	// port does. The command still runs, with its default buffering, which
	// is the same tradeoff nice makes for niceness. See the module comment.
	_ = set.modes

	if !os.exists(set.command[0]) && !set.command[0].contains('/')
		&& !set.command[0].contains('\\') {
		abs := os.find_abs_path_of_executable(set.command[0]) or { '' }
		if abs == '' {
			common.die(app_name, "failed to run command '${set.command[0]}': No such file or directory",
				127)
		}
	}
	if (set.command[0].contains('/') || set.command[0].contains('\\'))
		&& !os.exists(set.command[0]) {
		common.die(app_name, "failed to run command '${set.command[0]}': No such file or directory",
			127)
	}

	os.execvp(set.command[0], set.command[1..]) or {
		common.die(app_name, "failed to run command '${set.command[0]}': No such file or directory",
			127)
	}
}

const app_name = 'stdbuf'
