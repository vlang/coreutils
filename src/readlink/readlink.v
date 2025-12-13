import common
import os
import strings

const app = common.CoreutilInfo{
	name:        'readlink'
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

// resolve_link_fully keeps following a symlink until max_depth has been reached
// (in which case it errors) or a non-link target is found and returned.
fn resolve_link_fully(path string, max_depth int) !string {
	mut resolved_path := path
	for i := 0; i < max_depth; i++ {
		if lpath := do_readlink(resolved_path) {
			$if windows {
				// In Windows, a non-symlink will be resolved to itself
				if lpath == resolved_path {
					return resolved_path
				}
			}
			resolved_path = lpath
		} else {
			return resolved_path
		}
	}
	return error('Too many levels of symbolic links')
}

// canonicalize takes an absolute path and resolves each component of it if it is
// a symlink, depending on mode allowing or disallowing missing components
fn canonicalize(path string, mode CanonicalizeMode) !(string, bool) {
	assert os.is_abs_path(path)
	mut ok := true
	// mut res := ''
	mut sb := strings.new_builder(path.len)

	p := path.split(os.path_separator)
	// Windows UNC path?
	if path.len > 2 && (path[0] == `\\` || path[0] == `/`) && path[1] == path[0] {
		sb.write_string(path[0..2])
	} else {
		sb.write_string(p[0])
	}
	// Start at 1, the root has already been added
	for i := 1; i < p.len; i++ {
		if res := resolve_link_fully(os.join_path(sb.after(0), p[i]), max_link_depth) {
			if os.is_abs_path(res) {
				sb.clear()
				sb.write_string(res)
			} else {
				sb.write_string(os.path_separator + res)
			}
		} else {
			return err
		}
		if mode == .all_must_exist || (mode == .all_but_last_must_exist && i < p.len - 1) {
			if !os.exists(sb.after(0)) {
				ok = false
			}
		}
	}
	return os.abs_path(sb.str()), ok
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
