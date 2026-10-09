module realpath

import os

pub struct Settings {
pub mut:
	must_exist      bool // -e: every component must exist
	allow_missing   bool // -m: no component needs to exist
	no_symlinks     bool // -s: canonicalise without resolving links
	zero_terminated bool // -z
	quiet           bool // -q
	relative_to     string
	relative_base   string
	operands        []string
}

// resolve turns one operand into the text GNU would print for it.
pub fn resolve(path string, set Settings) !string {
	if path == '' {
		return error_with_code('', 1)
	}
	mut abs := absolute(path)

	if !set.no_symlinks {
		abs = canonical(abs)
	} else {
		abs = lexical(abs)
	}
	abs = strip_trailing(abs)

	check_exists(abs, path, set)!

	mut out := ''
	if set.relative_base != '' {
		base := canonical(absolute(set.relative_base))
		if under(abs, base) {
			out = relative_from(abs, base)
		} else {
			// Not both under the base, so the resolved path is printed as-is.
			out = abs
		}
	} else if set.relative_to != '' {
		base := if set.allow_missing {
			lexical(absolute(set.relative_to))
		} else {
			canonical(absolute(set.relative_to))
		}
		out = relative_from(abs, base)
	} else {
		out = abs
	}
	return native_separators(out)
}

// native_separators gives a Windows caller back the backslash form it
// expects, matching what uutils and the Windows shell produce.
fn native_separators(p string) string {
	$if windows {
		return p.replace('/', '\\')
	} $else {
		return p
	}
}

// absolute makes path absolute without resolving anything in it.
fn absolute(path string) string {
	mut p := path.replace('\\', '/')
	if p.len > 1 && p[1] == `:` {
		// Already drive-qualified on Windows.
		if p.len == 2 {
			p += '/'
		}
		return p
	}
	if p.starts_with('/') {
		// A root-relative path on Windows still needs a drive letter.
		cwd := os.getwd().replace('\\', '/')
		drive := if cwd.len > 1 && cwd[1] == `:` { cwd[..2] } else { '/' }
		return drive + p
	}
	mut cwd := os.getwd().replace('\\', '/')
	for cwd.len > 1 && cwd.ends_with('/') {
		cwd = cwd[..cwd.len - 1]
	}
	return cwd + '/' + p
}

// lexical collapses '.' and '..' textually, without touching the filesystem.
fn lexical(p string) string {
	parts := split_parts(p)
	mut out := []string{}
	for c in parts {
		if c == '.' {
			continue
		}
		if c == '..' {
			if out.len > 0 {
				out.delete_last()
			}
			continue
		}
		out << c
	}
	root, _ := root_and_body(p)
	mut s := root
	for c in out {
		s += c
		s += '/'
	}
	if s.len > root.len {
		s = s[..s.len - 1]
	}
	return s
}

// canonical resolves symbolic links by repeatedly resolving the longest
// prefix that exists, then continuing into whatever is left. os.real_path is
// used because V's standard library exposes no read_link, and it needs the
// path to exist, which is why the walk stops at the first missing component.
fn canonical(p string) string {
	mut cur := lexical(p)
	for {
		if !os.exists(cur) {
			// Resolve the deepest ancestor that does exist, then re-attach.
			parts := split_parts(cur)
			root, _ := root_and_body(cur)
			mut prefix := root
			mut i := 0
			for i < parts.len {
				candidate := if prefix == root { root + parts[i] } else { prefix + '/' + parts[i] }
				if os.exists(candidate) {
					prefix = candidate
					i++
				} else {
					break
				}
			}
			if prefix == cur {
				return cur
			}
			// The remainder is collapsed lexically, since nothing there is a
			// link that can be followed.
			mut tail := ''
			for j := i; j < parts.len; j++ {
				tail += parts[j]
				tail += '/'
			}
			if tail.len > 0 {
				tail = tail[..tail.len - 1]
			}
			cur = if tail == '' { prefix } else { prefix + '/' + tail }
			return lexical(cur)
		}
		// The path exists, so ask the OS to resolve it and repeat until the
		// answer stops moving.
		real := os.real_path(cur).replace('\\', '/')
		if real == '' {
			return cur
		}
		real_lex := lexical(real)
		if real_lex == cur {
			return cur
		}
		cur = real_lex
	}
	return cur
}

fn strip_trailing(p string) string {
	mut s := p
	for s.len > 1 && s.ends_with('/') {
		s = s[..s.len - 1]
	}
	return s
}

fn split_parts(p string) []string {
	mut s := p.replace('\\', '/')
	mut body := s
	if s.len > 1 && s[1] == `:` {
		body = s[2..]
	} else if s.starts_with('//') {
		// UNC: keep the whole prefix as the root.
		mut parts := s.split('/')
		mut i := 0
		for i < parts.len && parts[i] == '' {
			i++
		}
		if i + 1 < parts.len {
			return parts[i + 2..]
		}
		return []string{}
	}
	mut out := []string{}
	for c in body.split('/') {
		if c != '' {
			out << c
		}
	}
	return out
}

// root_and_body returns the leading separator prefix and the path after it.
fn root_and_body(p string) (string, []string) {
	s := p.replace('\\', '/')
	if s.starts_with('//') {
		parts := s.split('/')
		mut i := 0
		for i < parts.len && parts[i] == '' {
			i++
		}
		if i + 1 < parts.len {
			return '/' + parts[i] + '/' + parts[i + 1], parts[i + 2..]
		}
	}
	if s.len > 1 && s[1] == `:` {
		return s[..2] + '/', split_parts(s)
	}
	if s.starts_with('/') {
		return '/', split_parts(s)
	}
	return '', split_parts(s)
}

// check_exists enforces the -e / -m / default existence rules. The default
// requires every component but the last to exist, which is why a missing
// final name is fine and a missing directory in the middle is not.
fn check_exists(abs string, original string, set Settings) ! {
	if set.allow_missing {
		return
	}
	root, parts := root_and_body(abs)
	mut prefix := root
	for i, c in parts {
		is_last := i == parts.len - 1
		prefix = if prefix == root { root + c } else { prefix + '/' + c }
		if os.exists(prefix) {
			continue
		}
		if is_last && !set.must_exist {
			return
		}
		if set.quiet {
			exit(0)
		}
		return error_with_posix('${original}: No such file or directory', 1)
	}
}

// under reports whether path sits below base. The character after the shared
// prefix has to be a separator, so /usr/local/bin is not below /usr/loc. It is
// public so this boundary is testable without a matching filesystem.
pub fn under(path string, base string) bool {
	if base == '' {
		return false
	}
	if !path.starts_with(base) {
		return false
	}
	if path.len == base.len {
		return true
	}
	next := path[base.len]
	return next == `/` || next == `\\`
}

// relative_from expresses target relative to base, using '..' where the two
// diverge. It is public so the arithmetic can be tested without a filesystem.
pub fn relative_from(target string, base string) string {
	t := strip_trailing(target)
	b := strip_trailing(base)
	if t == b {
		return '.'
	}
	mut tp := split_parts(t)
	mut bp := split_parts(b)
	mut common := 0
	for common < tp.len && common < bp.len && tp[common] == bp[common] {
		common++
	}
	mut out := []string{}
	for _ in 0 .. (bp.len - common) {
		out << '..'
	}
	for i := common; i < tp.len; i++ {
		out << tp[i]
	}
	if out.len == 0 {
		return '.'
	}
	return out.join('/')
}

// error_with_posix produces the diagnostic GNU prints, tagged so the caller
// can tell an operand failure (exit 1) from a success.
fn error_with_posix(msg string, code int) IError {
	return error_with_code(msg, code)
}
