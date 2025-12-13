import os
import common

struct Linker {
	force              bool
	follow_symbolic    bool
	no_follow_symbolic bool
	symbolic           bool
	target             string
	sources            []string
mut:
	is_file_target bool
}

fn (ln Linker) is_target_dir() bool {
	return !ln.is_file_target
}

fn (mut ln Linker) run() {
	ln.validate()
	if ln.is_target_dir() && ln.sources.len > 1 {
		ln.link_to_dir()
	} else {
		ln.link(os.real_path(ln.sources.first()), os.real_path(ln.target))
	}
	exit(0)
}

fn (ln Linker) link_to_dir() {
	for source in ln.sources {
		if !os.exists(source) {
			common.exit_with_error_message(name, '${source} does not exist')
		}
		ln.link(os.real_path(source), os.join_path(os.real_path(ln.target), source))
	}
}

fn (ln Linker) link(source_path string, target_path string) {
	if os.exists(target_path) {
		if ln.force {
			os.rm(target_path) or { common.exit_with_error_message(name, err.msg()) }
		} else {
			common.exit_with_error_message(name, '${target_path} already exists')
		}
	}
	if ln.symbolic {
		os.symlink(source_path, target_path) or { common.exit_with_error_message(name, err.msg()) }
	} else {
		if os.is_dir(source_path) {
			common.exit_with_error_message(name, 'only symbolic links are supported for directories')
		}
		os.link(source_path, target_path) or { common.exit_with_error_message(name, err.msg()) }
	}
	println('${target_path} -> ${source_path}')
}

fn (mut ln Linker) validate() {
	if !os.exists(ln.target) && ln.sources.len > 1 {
		common.exit_with_error_message(name, '${ln.target} does not exist')
	}

	if os.is_file(ln.target) {
		ln.is_file_target = true
	} else {
		ln.is_file_target = false
	}

	if ln.sources.len > 1 && !ln.is_target_dir() {
		common.exit_with_error_message(name, '${ln.target} is not a directory')
	}
}
