import os

enum OverwriteMode {
	force
	interactive
	no_clobber
}

struct MvCommand {
	overwrite           OverwriteMode
	update              bool
	verbose             bool
	target_directory    string
	no_target_directory bool
}

fn (m MvCommand) run(source string, dest string) {
	if !os.exists(source) {
		eprintln(not_exist(source))
		return
	}
	if m.verbose || m.overwrite != .force {
		m.move(source, dest)
	} else {
		os.mv(source, dest) or { error_exit(name, err.msg) }
	}
}

fn (m MvCommand) move(src string, dst string) {
	ndst := if os.is_dir(dst) {
		os.join_path(dst.trim_right(os.path_separator), os.file_name(src.trim_right(os.path_separator)))
	} else {
		dst
	}

	rdst := $if windows { ndst.replace('/', '\\') } $else { ndst }
	if !m.int_yes(rdst) {
		return
	}
	os.mv(src, rdst) or { return }
	if m.verbose {
		println(renamed(src, dst))
	}
}

fn (m MvCommand) int_yes(path string) bool {
	if os.exists(path) {
		match m.overwrite {
			.no_clobber { return false }
			.interactive { return int_yes(prompt_file(path)) }
			.force { return true }
		}
	}
	return true
}
