import os
import common

enum OverwriteMode {
	force
	interactive
	no_clobber
}

struct MvCommand {
	overwrite           OverwriteMode
	update              bool
	verbose             bool
	progress            bool
	target_directory    string
	no_target_directory bool
}

fn (m MvCommand) run(source string, dest string) {
	if !os.exists(source) {
		eprintln(not_exist(source))
		return
	}
	if m.verbose || m.progress || m.overwrite != .force {
		m.move(source, dest)
	} else {
		os.mv(source, dest) or { error_exit(name, err.msg()) }
	}
}

fn (m MvCommand) move(src string, dst string) {
	ndst := if os.is_dir(dst) {
		os.join_path(dst.trim_right(os.path_separator),
			os.file_name(src.trim_right(os.path_separator)))
	} else {
		dst
	}

	rdst := $if windows { ndst.replace('/', '\\') } $else { ndst }
	if !m.int_yes(rdst) {
		return
	}
	if m.progress {
		mut bar := common.new_progress_bar(common.dir_size(src))
		if os.is_dir(src) {
			move_dir_progress(src, rdst, mut bar)
		} else {
			move_file_progress(src, rdst, mut bar)
		}
		bar.finish()
	} else {
		os.mv(src, rdst) or { return }
	}
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
