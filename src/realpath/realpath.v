import common
import flag
import os
import strings

const app = common.CoreutilInfo{
	name:        'realpath'
	description: 'print the resolved absolute file name'
}

const max_link_depth = 32

enum CanonicalizeMode {
	all_must_exist
	all_but_last_must_exist
	none_need_exist
}

enum ResolveMode {
	logical
	physical
}

struct Settings {
mut:
	mode         CanonicalizeMode
	resolve_mode ResolveMode
	quiet        bool
	strip        bool
	zero         bool
	relative_to  string
	relative_base string
	target_files []string
}

fn resolve_link_fully(path string, max_depth int) !string {
	mut resolved_path := path
	for i := 0; i < max_depth; i++ {
		if lpath := do_readlink(resolved_path) {
			$if windows {
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

fn canonicalize(path string, mode CanonicalizeMode, resolve_mode ResolveMode) !(string, bool) {
	assert os.is_abs_path(path)
	mut ok := true
	mut sb := strings.new_builder(path.len)

	p := path.split(os.path_separator)
	if path.len > 2 && (path[0] == `\\` || path[0] == `/`) && path[1] == path[0] {
		sb.write_string(path[0..2])
	} else {
		sb.write_string(p[0])
	}
	for i := 1; i < p.len; i++ {
		if resolve_mode == .logical {
			if p[i] == '..' {
				if sb.len > 1 {
					cur := sb.str()
					parent := os.dir(cur)
					if parent != cur {
						sb.clear()
						sb.write_string(parent)
					}
				}
				continue
			}
			if p[i] == '.' {
				continue
			}
		}
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

fn canonicalize_strip(path string) string {
	mut sb := strings.new_builder(path.len)
	p := path.split(os.path_separator)
	if path.len > 2 && (path[0] == `\\` || path[0] == `/`) && path[1] == path[0] {
		sb.write_string(path[0..2])
	} else {
		sb.write_string(p[0])
	}
	for i := 1; i < p.len; i++ {
		if p[i] == '..' {
			if sb.len > 1 {
				cur := sb.str()
				parent := os.dir(cur)
				if parent != cur {
					sb.clear()
					sb.write_string(parent)
				}
			}
			continue
		}
		if p[i] == '.' {
			continue
		}
		sb.write_string(os.path_separator + p[i])
	}
	return os.abs_path(sb.str())
}

fn make_relative(path string, base string) string {
	if base == '' {
		return path
	}
	if !os.is_abs_path(base) {
		return path
	}
	if path == base {
		return '.'
	}
	if path.starts_with(base + os.path_separator) {
		return path[base.len + 1..]
	}
	if base.starts_with(path + os.path_separator) {
		mut rel := ''
		rest := base[path.len + 1..]
		for part in rest.split(os.path_separator) {
			if part == '' {
				continue
			}
			if rel == '' {
				rel = '..'
			} else {
				rel += '/..'
			}
		}
		return rel
	}
	mut rel := ''
	mut p := path
	for p != base && !p.starts_with(base + os.path_separator) {
		parent := os.dir(p)
		if parent == p {
			break
		}
		if rel == '' {
			rel = '..'
		} else {
			rel = '../' + rel
		}
		p = parent
	}
	if p == base {
		return rel
	}
	if p.starts_with(base + os.path_separator) {
		rel += '/' + p[base.len + 1..]
	}
	return rel
}

fn realpath(settings Settings) {
	mut exit_code := 0
	for path in settings.target_files {
		abs := os.abs_path(path)
		if settings.strip {
			mut result := canonicalize_strip(abs)
			if settings.relative_to != '' {
				result = make_relative(result, settings.relative_to)
			} else if settings.relative_base != '' {
				if !result.starts_with(settings.relative_base + os.path_separator)
					&& result != settings.relative_base {
				} else {
					result = make_relative(result, settings.relative_base)
				}
			}
			if settings.zero {
				print(result)
				print(u8(0).ascii_str())
			} else {
				println(result)
			}
		} else {
			if cpath, exists := canonicalize(abs, settings.mode, settings.resolve_mode) {
			if !exists {
				if !settings.quiet {
					app.eprintln('${path}: No such file or directory')
					exit_code = 1
				}
				} else {
					mut out := cpath
					if settings.relative_to != '' {
						out = make_relative(out, settings.relative_to)
					} else if settings.relative_base != '' {
						if !out.starts_with(settings.relative_base + os.path_separator)
							&& out != settings.relative_base {
							// keep absolute
						} else {
							out = make_relative(out, settings.relative_base)
						}
					}
				if settings.zero {
					print(out)
					print(u8(0).ascii_str())
				} else {
					println(out)
				}
				}
		} else {
			if !settings.quiet {
				app.eprintln('${path}: ${err.msg()}')
				exit_code = 1
			}
		}
		}
	}
	exit(exit_code)
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	canon_all := fp.bool('canonicalize-existing', `e`, false,
		'canonicalize by following every symlink in every component of the given name recursively, all components must exist')
	canon_none := fp.bool('canonicalize-missing', `m`, false,
		'canonicalize by following every symlink in every component of the given name recursively, without requirements on components existence')
	logical := fp.bool('logical', `L`, false,
		'resolve .. components before symlinks')
	_ = fp.bool('physical', `P`, false,
		'resolve symlinks as encountered (default)', flag.FlagConfig{})
	st.quiet = fp.bool('quiet', `q`, false, 'suppress most error messages')
	st.strip = fp.bool('strip', `s`, false, 'don\'t expand symlinks')
	_ = fp.bool('no-symlinks', 0, false, 'don\'t expand symlinks', flag.FlagConfig{})
	st.zero = fp.bool('zero', `z`, false, 'end each output line with NUL, not newline')
	rel_to := fp.string('relative-to', 0, '', 'print the resolved path relative to DIR')
	rel_base := fp.string('relative-base', 0, '', 'print absolute paths except for PATHs beneath DIR')
	st.relative_to = if rel_to != '' { os.abs_path(rel_to) } else { '' }
	st.relative_base = if rel_base != '' { os.abs_path(rel_base) } else { '' }
	mut rem_pars := fp.remaining_parameters()
	if rem_pars.len == 0 {
		app.quit(message: 'missing operand', show_help_advice: true)
	}
	if canon_all {
		st.mode = .all_must_exist
	} else if canon_none {
		st.mode = .none_need_exist
	} else {
		st.mode = .all_but_last_must_exist
	}
	if logical {
		st.resolve_mode = .logical
	} else {
		st.resolve_mode = .physical
	}
	st.target_files = rem_pars
	return st
}

fn main() {
	realpath(args())
}
