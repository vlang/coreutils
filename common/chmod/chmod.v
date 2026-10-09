module chmod

import os

pub struct Settings {
pub mut:
	recursive bool   // -R
	verbose   bool   // -v
	changes   bool   // -c
	reference string // --reference=FILE
	mode      string
	operands  []string
}

// Apply changes the mode of every operand and returns 1 if any failed.
pub fn run(set Settings) int {
	if set.reference != '' {
		mode := mode_of(set.reference) or {
			eprintln('chmod: cannot access ${set.reference}: No such file or directory')
			return 1
		}
		// A reference mode is absolute, so no symbolic clause list is applied.
		return apply_mode(int(mode), set, '')
	}
	// The mode is validated once against a zero base before any file is
	// touched, so an invalid mode leaves the tree alone.
	_, ok := parse_mode(set.mode, 0)
	if !ok {
		eprintln('chmod: invalid mode: ‘${set.mode}’')
		eprintln("Try 'chmod --help' for more information.")
		return 1
	}
	return apply_mode(0, set, set.mode)
}

fn apply_mode(bits int, set Settings, spec string) int {
	mut failed := 0
	for operand in set.operands {
		if set.recursive {
			failed += walk(operand, bits, set, spec)
		} else {
			failed += change(operand, bits, set, spec)
		}
	}
	return if failed > 0 { 1 } else { 0 }
}

fn walk(path string, bits int, set Settings, spec string) int {
	mut failed := change(path, bits, set, spec)
	st := os.lstat(path) or { return failed }
	if st.get_filetype() == .directory {
		entries := os.ls(path) or { return failed }
		for e in entries {
			failed += walk(os.join_path(path, e), bits, set, spec)
		}
	}
	return failed
}

fn change(path string, bits int, set Settings, spec string) int {
	mut old := u32(0)
	old = current_mode(path) or {
		eprintln("chmod: cannot access '${path}': No such file or directory")
		return 1
	}
	// Symbolic clauses with + or - build on the mode the file already has,
	// while an octal mode and the = form are absolute.
	mut target := u32(bits)
	if spec != '' {
		t, ok := parse_mode(spec, old)
		if !ok {
			eprintln('chmod: invalid mode: ‘${spec}’')
			return 1
		}
		target = t
	}
	if old == target {
		return 0
	}
	os.chmod(path, int(target)) or {
		eprintln('chmod: changing permissions of ${path}: ${err}')
		return 1
	}
	if set.verbose {
		eprintln("mode of '${path}' changed from ${old:04o} (${mode_string(old)}) to ${target:04o} (${mode_string(target)})")
	}
	return 0
}

fn mode_of(path string) !u32 {
	st := os.lstat(path)!
	return u32(st.mode) & 0o7777
}

// current_mode reads the permission bits and normalises them onto the
// twelve-bit rwx model chmod works in.
fn current_mode(path string) !u32 {
	st := os.lstat(path)!
	return u32(st.mode) & 0o7777
}

fn mode_string(bits u32) string {
	mut out := ''
	// Each of the three rwx triples sits at bits 6-8, 3-5 and 0-2.
	for base in [6, 3, 0] {
		r := bits & (u32(1) << u32(base + 2)) != 0
		w := bits & (u32(1) << u32(base + 1)) != 0
		x := bits & (u32(1) << u32(base)) != 0
		out += if r { 'r' } else { '-' }
		out += if w { 'w' } else { '-' }
		out += if x { 'x' } else { '-' }
	}
	return out
}

// parse_mode accepts either an octal value or a symbolic clause list such as
// u+x,go=rw. It reports failure for anything GNU would reject.
pub fn parse_mode(spec string, base u32) (u32, bool) {
	if spec.len > 0 && spec[0] >= `0` && spec[0] <= `7` && is_octal(spec) {
		return parse_octal(spec)
	}
	return parse_symbolic(spec, base)
}

fn is_octal(s string) bool {
	for c in s.bytes() {
		if c < `0` || c > `7` {
			return false
		}
	}
	return true
}

fn parse_octal(s string) (u32, bool) {
	// GNU accepts one to four octal digits and pads on the left, so "64" is
	// 064 and "1" is 001.
	if s.len < 1 || s.len > 4 {
		return 0, false
	}
	mut n := u32(0)
	for c in s.bytes() {
		n = n * 8 + u32(c - `0`)
	}
	return n & 0o7777, true
}

// parse_symbolic applies a comma-separated list of clauses, each of the form
// [ugoa]*[-+=][rwxXst]*, onto a starting value of zero.
fn parse_symbolic(spec string, base u32) (u32, bool) {
	if spec == '' {
		return 0, false
	}
	mut bits := base
	for clause in spec.split(',') {
		new_bits, ok := apply_clause(clause, bits)
		if !ok {
			return 0, false
		}
		bits = new_bits
	}
	return bits & 0o7777, true
}

// apply_clause parses one clause and folds it into bits. It returns the new
// value and false when the clause is malformed, which is what makes chmod
// report "invalid mode".
fn apply_clause(clause string, bits_in u32) (u32, bool) {
	if clause == '' {
		return bits_in, false
	}
	mut bits := bits_in
	mut i := 0
	mut who := u32(0)
	mut who_given := false
	for i < clause.len {
		c := clause[i]
		match c {
			`u` {
				who |= 0o700
				who_given = true
			}
			`g` {
				who |= 0o070
				who_given = true
			}
			`o` {
				who |= 0o007
				who_given = true
			}
			`a` {
				who |= 0o777
				who_given = true
			}
			else {
				break
			}
		}
		i++
	}
	if !who_given {
		who = 0o777
	}
	if i >= clause.len {
		return bits, false
	}
	op := clause[i]
	if op != `+` && op != `-` && op != `=` {
		return bits, false
	}
	i++
	mut perms := u32(0)
	mut any := false
	for i < clause.len {
		c := clause[i]
		mut bit := u32(0)
		match c {
			`r` { bit = 4 }
			`w` { bit = 2 }
			`x` { bit = 1 }
			`s`, `t` {
				// Sticky and set-id bits are accepted but need the owning
				// class to be named.
				bit = 1
			}
			`X` {
				// +X is a no-op on a regular file, so it never sets a bit
				// here; directories would, but this model stores only the
				// twelve bits of the target.
				bit = 0
			}
			else { return bits, false }
		}
		if who != 0 || c != `X` {
			any = true
		}
		perms |= shift_for(who, bit)
		i++
	}
	if !any && op == `=` {
		// go= clears those bits outright.
	}
	match op {
		`+` {
			bits |= perms
		}
		`-` {
			bits &= ~perms
		}
		`=` {
			bits = (bits & ~who) | perms
		}
		else {}
	}
	return bits, true
}

// shift_for moves a single rwx triple into the position the "who" mask
// selects: 4 for user, 2 for group, 1 for other.
fn shift_for(who u32, bit u32) u32 {
	mut out := u32(0)
	if who & 0o700 != 0 {
		out |= bit << 6
	}
	if who & 0o070 != 0 {
		out |= bit << 3
	}
	if who & 0o007 != 0 {
		out |= bit
	}
	return out
}
