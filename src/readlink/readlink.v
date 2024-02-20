import common
import os
import strings

const app = common.CoreutilInfo{
	name: 'readlink'
	description: 'print resolved symbolic links or canonical file names'
}

const max_link_depth = 32

enum CanonicalizeMode {
	do_not
	all_must_exist
	all_but_last_must_exist
	none_need_exist
}

// Settings for Utility: readlink
struct Settings {
mut:
	canonicalize CanonicalizeMode
	no_newline   bool
	verbose      bool
	zero         bool
	target_files []string
	exit_code    u8
}

fn resolve_link_fully(path string, max_depth int) !string {
	mut resolved_path := path
	for i := 0; i < max_depth; i++ {
		if lpath := do_readlink(resolved_path) {
			resolved_path = lpath
		} else {
			// No further resolution found
			return resolved_path
		}
	}
	return error('Too many levels of symbolic links')
}

fn canonicalize(path string, mode CanonicalizeMode) !(string, bool) {
	mut ok := true
	mut sb := strings.new_builder(path.len)
	p := path.split(os.path_separator)
	for i := 0; i < p.len; i++ {
		resolved_path := resolve_link_fully(os.join_path(sb.after(0), p[i]), max_link_depth)!
		if resolved_path.starts_with(os.path_separator) {
			// Absolute path replaces everything that came before
			sb.clear()
			sb.write_string(resolved_path)
		} else {
			new_path := sb.after(0) + os.path_separator + resolved_path
			sb.clear()
			sb.write_string(os.abs_path(new_path))
		}
		if mode == .all_must_exist || (mode == .all_but_last_must_exist && i < p.len - 1) {
			if !os.exists(sb.after(0)) {
				ok = false
			}
		}
	}
	cpath := sb.str()
	return os.abs_path(cpath), ok
}

fn readlink(settings Settings) {
	mut exit_code := 0
	for path in settings.target_files {
		if settings.canonicalize != .do_not {
			if cpath, exists := canonicalize(os.abs_path(path), settings.canonicalize) {
				if !exists {
					app.eprintln('${path}: No such file or directory')
					exit_code = 1
				} else {
					println(cpath)
				}
			} else {
				app.eprintln('${path}: ${err.msg()}')
				exit_code = 1
			}
		} else {
			if resolved_path := do_readlink(path) {
				println(resolved_path)
			} else {
				if settings.verbose {
					app.eprintln('${path}: ${err.msg()}')
				}
				exit_code = 1
			}
		}
	}
	exit(exit_code)
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	canon := fp.bool('canonicalize', `f`, false, 'canonicalize by following every symlink in every component of the given name recursively; all but the last component must exist')
	canon_all := fp.bool('canonicalize-existing', `e`, false, 'canonicalize by following every symlink in every component of the given name recursively, all components must exist')
	canon_none := fp.bool('canonicalize-missing', `m`, false, 'canonicalize by following every symlink in every component of the given name recursively, without requirements on components existence')
	st.no_newline = fp.bool('no-newline', `n`, false, 'do not output the trailing delimiter')
	_ := fp.bool('quiet', `q`, false, '')
	_ := fp.bool('silent', `s`, true, 'suppress most error messages (on by default)')
	st.verbose = fp.bool('verbose', `v`, false, 'report error messages (overrides --quiet and --silent)')
	st.zero = fp.bool('zero', `f`, false, 'end each output line with NUL, not newline')
	mut rem_pars := fp.remaining_parameters()
	if st.no_newline && rem_pars.len > 1 {
		st.no_newline = false
		app.eprintln('ignoring --no-newline with multiple arguments')
	}
	if rem_pars.len == 0 {
		app.quit(message: 'missing operand', show_help_advice: true)
	}
	if canon {
		st.canonicalize = .all_but_last_must_exist
	} else if canon_all {
		st.canonicalize = .all_must_exist
	} else if canon_none {
		st.canonicalize = .none_need_exist
	} else {
		st.canonicalize = .do_not
	}
	st.target_files = rem_pars
	return st
}

fn main() {
	readlink(args())
}
