module du

import os

// Block-size output mode. -b is a mode rather than a flag because it means
// "one byte per block", which overrides -k/-B the way -i does in df.
pub enum Mode {
	human
	si_human
	kibibytes
	mebibytes
	gibibytes
	blocks
	bytes
}

pub struct Settings {
pub mut:
	mode       Mode = .kibibytes
	block_size int  = 1024
	summary    bool // -s: one line per operand only
	all        bool // -a: include every file, not just directories
	total      bool // -c, --total: add a grand total line
	max_depth  int = max_depth_unset
	operands   []string
}

const max_depth_unset = -1

// report walks the operands and returns the table text plus whether any path
// failed. GNU reports a failure and keeps going with the other operands, then
// exits 1, so the two are kept separate rather than folded into an error.
pub fn report(set Settings) (string, bool) {
	mut lines := []string{}
	mut grand := u64(0)
	mut failed := false

	mut roots := []string{}
	if set.operands.len == 0 {
		roots = ['.']
	} else {
		roots = set.operands.clone()
	}

	for root in roots {
		st := os.lstat(root) or {
			lines << 'du: cannot access ${root}: ${reason(err)}'
			failed = true
			continue
		}
		mut size := u64(0)
		if st.get_filetype() == .directory {
			size = walk_dir(root, 0, set, mut lines)
			lines << row(size, root, set)
		} else {
			// A file named on the command line is always shown, -a or not.
			size = st.size
			lines << row(size, root, set)
		}
		grand += size
	}

	if set.total {
		lines << row(grand, 'total', set)
	}
	return lines.join('\n'), failed
}

// walk_dir returns the total size of everything under dir, appending one line
// per entry the depth and -a settings ask for.
fn walk_dir(dir string, depth int, set Settings, mut lines []string) u64 {
	entries := os.ls(dir) or { return 0 }.sorted()

	mut sum := u64(0)
	for name in entries {
		child := os.join_path(dir, name)
		st := os.lstat(child) or {
			lines << 'du: cannot access ${child}: ${reason(err)}'
			continue
		}
		if st.get_filetype() == .directory {
			sub := walk_dir(child, depth + 1, set, mut lines)
			sum += sub
			if !set.summary && within_depth(depth + 1, set) {
				lines << row(sub, child, set)
			}
		} else {
			sum += st.size
			// -s asks for one line per operand, so files under it are not
			// listed even with -a.
			if set.all && !set.summary && within_depth(depth + 1, set) {
				lines << row(st.size, child, set)
			}
		}
	}
	return sum
}

// within_depth reports whether an entry this far below the operand should be
// printed. The operand itself is depth 0 and is always printed.
fn within_depth(depth int, set Settings) bool {
	return set.max_depth < 0 || depth <= set.max_depth
}

// human_readable prints at most four significant characters: one decimal
// below 10 and none at or above it. si selects powers of 1000 over 1024.
//
// This duplicates common/df's copy deliberately. Each util in this repository
// has to merge to main on its own, so depending on another util's unmerged
// module would block the pull request rather than share the code. Once both
// have landed this is worth folding into one place.
pub fn human_readable(bytes u64, si bool) string {
	base := if si { u64(1000) } else { u64(1024) }
	// --si keeps the SI 'k' but the conventional M, G, T for the rest;
	// --human-readable uses K for the first unit.
	units := if si { 'kMGTPEZY' } else { 'KMGTPEZY' }

	mut value := f64(bytes)
	mut idx := 0
	for idx < units.len && value >= f64(base) {
		value /= f64(base)
		idx++
	}

	mut body := if idx > 0 && value < 10.0 {
		'${value:.1f}'
	} else {
		'${value:.0f}'
	}
	if idx > 0 {
		body += units[idx - 1].ascii_str()
	}
	return body
}

fn row(size u64, path string, set Settings) string {
	return '${format_size(size, set)}\t${path}'
}

pub fn format_size(bytes u64, set Settings) string {
	match set.mode {
		.bytes {
			return bytes.str()
		}
		.human {
			return human_readable(bytes, false)
		}
		.si_human {
			return human_readable(bytes, true)
		}
		.blocks {
			if set.block_size <= 0 {
				return bytes.str()
			}
			return (bytes / u64(set.block_size)).str()
		}
		else {
			mut div := u64(1024)
			match set.mode {
				.mebibytes { div = u64(1024) * 1024 }
				.gibibytes { div = u64(1024) * 1024 * 1024 }
				else {}
			}
			return ceil_div(bytes, div).str()
		}
	}
}

// ceil_div rounds up, because a path of one byte still occupies a whole block
// and GNU reports that as one block rather than zero.
fn ceil_div(bytes u64, div u64) u64 {
	if div == 0 {
		return bytes
	}
	return (bytes + div - 1) / div
}

// reason maps a V error message onto the wording GNU uses, so the diagnostics
// read like the rest of this port's output.
fn reason(err IError) string {
	m := err.msg()
	if m.contains('cannot find the file') {
		return 'No such file or directory'
	}
	if m.contains('Access is denied') {
		return 'Permission denied'
	}
	return m
}
