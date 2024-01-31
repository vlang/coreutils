import os

enum OverwriteMode {
	force
	interactive
	no_clobber
}

struct CpCommand {
	overwrite           OverwriteMode
	update              bool
	verbose             bool
	target_directory    string
	no_target_directory bool
	recursive           bool
}

fn (c CpCommand) run(source string, dest string) {
	if !os.exists(source) {
		eprintln(not_exist(source))
		return
	}
	if c.verbose || c.overwrite != .force {
		c.copy(source, dest)
	} else {
		if os.is_dir(source) && !c.recursive {
			eprintln(not_recursive(source))
			return
		}
		os.cp(source, dest) or { error_exit(name, err.msg) }
	}
}

fn (c CpCommand) copy(src string, dst string) {
	ndst := if os.is_dir(dst) {
		os.join_path(dst.trim_right(os.path_separator), os.file_name(src.trim_right(os.path_separator)))
	} else {
		dst
	}

	rdst := $if windows { ndst.replace('/', '\\') } $else { ndst }
	if !c.int_yes(rdst) {
		return
	}
	os.cp(src, rdst) or { return }
	if c.verbose {
		println(renamed(src, dst))
	}
}

fn (c CpCommand) int_yes(path string) bool {
	if os.exists(path) {
		match c.overwrite {
			.no_clobber { return false }
			.interactive { return int_yes(prompt_file(path)) }
			.force { return true }
		}
	}
	return true
}
