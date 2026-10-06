// A progress bar for cp and mv's -progress, drawn on standard error so it does not
// interfere with the tool's own output on standard output. advcpmv draws on stderr
// too.
module common

import os

struct ProgressBar {
	total int
	width int
mut:
	current int
}

pub fn new_progress_bar(total int) ProgressBar {
	return ProgressBar{
		total: total
		width: 40
	}
}

pub fn (mut b ProgressBar) update(n int) {
	b.current += n
	pct := if b.total > 0 { b.current * 100 / b.total } else { 100 }
	mut filled := if b.total > 0 { b.current * b.width / b.total } else { b.width }
	if filled > b.width {
		filled = b.width
	}
	mut bar := ''
	for i in 0 .. b.width {
		bar += if i < filled { '=' } else { ' ' }
	}
	// Carriage return returns to the start of the line, so the next update
	// overwrites this one rather than scrolling.
	eprint('\r[${bar}] ${pct}%')
}

pub fn (mut b ProgressBar) finish() {
	eprint('\n')
}

// dir_size totals the bytes under a path, walking directories. This is what the
// bar needs before it starts, and it is why -progress is slower than a plain
// copy: the whole tree is stat'd before the first byte moves.
pub fn dir_size(path string) int {
	if !os.is_dir(path) {
		return os.file_size(path)
	}
	mut total := 0
	entries := os.ls(path) or { [] }
	for entry in entries {
		total += dir_size(os.join_path(path, entry))
	}
	return total
}
