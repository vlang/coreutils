// module rmutil
import os

//** RmCommand struct to hold values **
struct RmCommand {
	recursive bool
	// -r
	dir bool
	// -d
	interactive bool
	// -i, always
	verbose bool
	// -v
	force bool
	// -f
	less_int bool
	// -I, once
}

// If user confirmation needed at top, take it. Returns whether program can continue
fn (r RmCommand) confirm_int_once(len int) bool {
	if !r.less_int || r.interactive {
		return true
	}
	return if len > 3 {
		int_yes(rem_args(len))
	} else if r.recursive {
		int_yes(rem_recurse(len))
	} else {
		true
	}
}

// Handle if path is a dir
fn (r RmCommand) rm_dir(path string) {
	if !r.recursive {
		if !r.dir {
			error_message(name, err_is_dir(path))
			return
		}

		// --dir flag set, so remove if empty dir
		if !os.is_dir_empty(path) {
			error_message(name, err_is_dir_empty(path))
			return
		}

		os.rmdir(path) or { eprintln(err.msg) }
		return
	}

	// Can just delete all
	if !r.interactive && !r.verbose {
		os.rmdir_all(path) or { eprintln(err.str()) }
		return
	}

	// Need to go through recursively to print/interact
	r.rm_dir_verbose_inter(path)
}

// Handle if verbose or interactive. Returns whether curr subdir is successfully deleted
fn (r RmCommand) rm_dir_verbose_inter(path string) bool {
	if !r.int_yes(prompt_descend(path)) {
		return true
	}

	items := os.ls(path) or {
		eprintln(err.str())
		return false
	}
	mut ok := true
	for item in items {
		curr_path := os.join_path(path, item)
		if os.is_dir(curr_path) {
			ok = ok && r.rm_dir_verbose_inter(curr_path)
			continue
		}

		// item is a file
		if !r.int_yes(prompt_file(curr_path)) {
			continue
		}

		os.rm(curr_path) or {
			eprintln(err.str())
			return false
		}
		if r.verbose {
			println(rem(curr_path))
		}
	}

	if r.int_yes(prompt_dir(path)) {
		os.rmdir(path) or {
			eprintln(err.str())
			return false
		}
		if r.verbose {
			println(rem(path))
		}
	}

	return ok
}

// Take user confirmation if necessary
fn (r RmCommand) int_yes(prompt string) bool {
	// println(r.interactive)
	// println(r.force)
	return !r.interactive || r.force || int_yes(prompt)
}

// Entry point into rm logic.
fn (r RmCommand) rm_path(path string) {
	if !os.exists(path) {
		error_message(name, err_not_exist(path))
		return
	}

	// println('here')
	if os.is_dir(path) {
		r.rm_dir(path)
		return
	}
	if r.int_yes(prompt_file(path)) {
		os.rm(path) or { error_message(name, err.msg) }
		if r.verbose {
			println(rem(path))
		}
	}
}
