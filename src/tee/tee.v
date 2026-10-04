import common
import os

const app_name = 'tee'

fn main() {
	set := args()!
	tee(set)
}

// tee copies standard input to standard output and to every file named, which is
// what GNU does and what nothing else in this repository did: src/tee held a
// delete.me and nothing else.
fn tee(set Settings) {
	mut exit_code := 0
	mut sinks := []os.File{}
	// -a appends and without it the file is truncated, so the two are opened
	// differently rather than opened twice.
	for path in set.files {
		sink := open_sink(path, set.append) or {
			// GNU prints the system's own reason for the file, which is what a caller
			// reads to tell a missing file from one it may not write. That is measured
			// for the missing case and left to V for the rest, rather than guessed at:
			// before, every failure that was not "no such file" was reported as
			// "Permission denied" whether or not that was true.
			reason := if os.exists(path) { err.msg() } else { 'No such file or directory' }
			eprintln('${app_name}: ${path}: ${reason}')
			if set.error_mode != 'warn-no-fail' {
				exit_code = 1
			}
			continue
		}
		sinks << sink
	}

	// Standard input is read a line at a time and written out unchanged, newline
	// included, so a file that does not end in one stays that way. That matters
	// because tee is expected to be byte for byte what came in: measured against
	// GNU 9.4 with input that has no trailing newline, and with input that has one,
	// both come out the same here.
	for {
		line := os.get_raw_line()
		if line.len == 0 {
			break
		}
		print(line)
		flush_stdout()
		for mut sink in sinks {
			sink.write_string(line) or {
				eprintln('${app_name}: write error')
				exit(1)
			}
		}
	}
	for mut sink in sinks {
		sink.close()
	}
	exit(exit_code)
}

fn open_sink(path string, append bool) !os.File {
	// Written out rather than as one expression of two Results, which V does not let
	// a function return in one arm and the other.
	if append {
		return os.open_append(path)
	}
	return os.create(path)
}

struct Settings {
	files      []string
	append     bool
	error_mode string
}

fn args() !Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('Copy standard input to each FILE, and also to standard output.')

	append := fp.bool('append', `a`, false, 'append to the given FILEs, do not overwrite')
	ignore_interrupts := fp.bool('ignore-interrupts', `i`, false,
		'ignore interrupt signals')
	error_mode := fp.string('output-error', `p`, 'warn',
		'error handling mode: warn|warn-no-fail|exit|die')

	files := fp.remaining_parameters()

	// -i is accepted and does nothing here: there is no signal handling in this
	// implementation to be interrupted from, and saying so here beats failing on an
	// option GNU takes.
	_ := ignore_interrupts

	if error_mode !in ['warn', 'warn-no-fail', 'exit', 'die'] {
		return error("argument to --output-error invalid: '${error_mode}'")
	}

	return Settings{
		files:      files
		append:     append
		error_mode: error_mode
	}
}
