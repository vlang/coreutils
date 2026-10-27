#!/bin/env v

// gnu_test_suite.vsh - run the GNU coreutils test suite against our binaries.
//
// This is the measurement that no number of unit tests substitutes for: it runs
// the tests GNU writes for its own implementation, against ours, and reports
// which pass.
//
// The flow mirrors what uutils/coreutils does, and is not original work:
//
//   fetch the release tarball, configure it, copy lib/stdckdint.in.h over
//   lib/stdckdint.h, build it, point tests/local.mk at our bin/ directory
//   instead of GNU's own src/, and run `make check`.
//
// Building GNU at all needs one workaround on Ubuntu 24.04: the tree ships
// lib/stdckdint.in.h, gnulib's replacement for the C23 header that gcc 13 does
// not provide, but the make rule that copies it into place never fires, so
// lib/malloca.c fails on `#include <stdckdint.h>`. Copying it by hand is the
// whole fix - the file has no substitution markers in it.
//
// Pointing the tests at our binaries is done in two places, because the tests
// find their subject through two independent mechanisms: the PATH= line in
// tests/local.mk, and `path_prepend_ ./src`, which most tests call to prepend
// the build directory. Patching only the first leaves every test silently
// measuring GNU. uutils strips the second by rewriting the test files; this does
// the same.
//
// Usage:
//   v run util/gnu_test_suite.vsh [--tag v9.4] [--bin-dir bin] [--work-dir .gnu]
//                                 [--only <tool>] [--jobs N]

import os

const usage = 'Usage: v run util/gnu_test_suite.vsh [OPTIONS]

Run the GNU coreutils test suite against the binaries this repo builds.

  --tag TAG         GNU coreutils release tag to fetch, default v9.4
  --bin-dir DIR     directory holding our built tools, default bin
  --work-dir DIR    where the GNU sources are kept, default .gnu
  --setup           fetch, configure and build GNU, then stop
  --only TOOL       restrict the run to one tool, such as cut
  --jobs N          parallelism for the GNU build, default 4
  --help            show this help
'

struct Config {
mut:
	tag      string = 'v9.4'
	bin_dir  string = 'bin'
	work_dir string = '.gnu'
	setup    bool
	run      bool = true
	only     string
	list     bool
	jobs     int = 4
	help     bool
}

// gnu_version is the tag without a leading v, because the tarball and the
// directory it unpacks into are both named coreutils-9.4 for the tag v9.4.
fn gnu_version(tag string) string {
	return if tag.starts_with('v') { tag[1..] } else { tag }
}

// run_shell runs a shell script with positional arguments, and reports its
// status and output. The arguments are passed rather than interpolated so that
// the script can use "$1" and friends without V rewriting them.
fn run_shell(args []string) (int, string) {
	res := os.exec(args)
	return res.exit_code, res.output
}

// setup_gnu fetches, configures and builds GNU coreutils.
fn setup_gnu(gnu_root string, tag string, jobs int) ! {
	ver := gnu_version(tag)
	tarball := 'coreutils-${ver}.tar.xz'
	url := 'https://ftp.gnu.org/gnu/coreutils/coreutils-${ver}.tar.xz'

	if !os.exists(gnu_root) {
		println('> fetching ${url}')
		// The tarball is fetched and unpacked in the parent of gnu_root,
		// because unpacking inside gnu_root would nest a second copy of
		// coreutils-<ver> underneath it.
		parent := os.dir(gnu_root)
		os.mkdir_all(parent) or { return error('could not create ${parent}') }
		// Arguments are passed positionally rather than interpolated, so V
		// does not rewrite the shell's own "$1".
		script := 'set -e
root="$1"; tarball="$2"; url="$3"
cd "$root"
if [ ! -f "$tarball" ]; then
  curl -sSfL -o "$tarball" "$url"
fi
tar xf "$tarball"
'
		code, out := run_shell(['bash', '-c', script, 'fetch', os.abs_path(parent), tarball, url])
		if code != 0 {
			return error('fetch failed:\n${out}')
		}
	}

	marker := os.join_path(gnu_root, '.gnu-built')
	if os.exists(marker) {
		println('> GNU coreutils already built at ${gnu_root}')
		return
	}

	// Without this copy, lib/malloca.c fails on a C23 header that gcc 13 on
	// Ubuntu 24.04 does not ship, and the whole suite is unavailable.
	stdckdint := os.join_path(gnu_root, 'lib/stdckdint.h')
	if !os.exists(stdckdint) {
		script := 'set -e
root="$1"
cp "$root/lib/stdckdint.in.h" "$root/lib/stdckdint.h"
test -f "$root/lib/stdckdint.h"
'
		code, out := run_shell(['bash', '-c', script, 'stdckdint', os.abs_path(gnu_root)])
		if code != 0 {
			return error('could not install the stdckdint replacement header:\n${out}')
		}
	}

	println('> configuring GNU coreutils ${tag}')
	configure_script := 'set -e
cd "$1"
./configure -C --quiet --disable-nls --disable-dependency-tracking --disable-gcc-warnings --without-selinux
'
	code, out := run_shell(['bash', '-c', configure_script, 'configure', os.abs_path(gnu_root)])
	if code != 0 {
		return error('configure failed:\n${out}')
	}

	println('> building GNU coreutils, this takes a few minutes')
	build_script := 'set -e
root="$1"; jobs="$2"; log="$3"
cd "$root"
make -j"$jobs" > "$log" 2>&1
test -x src/cut
test -x src/getlimits
'
	code2, out2 := run_shell(['bash', '-c', build_script, 'build', os.abs_path(gnu_root), jobs.str(),
		os.join_path(os.abs_path(gnu_root), 'build.log')])
	if code2 != 0 {
		return error('build failed, see ${gnu_root}/build.log:\n${out2}')
	}
	os.write_file(marker, 'built\n') or {}
	println('> GNU coreutils built')
}

// patch_path points the suite at our binaries in two places, because the tests
// find their subject through two independent mechanisms:
//
//   the PATH= line in tests/local.mk, which sets the base PATH, and
//   `path_prepend_ ./src`, which most tests call to prepend the build directory.
//
// Patching only the first leaves the second prepending GNU's own src/ ahead of
// our bin/, so every test silently measures GNU. uutils strips the second by
// rewriting the test files; this does the same and leaves nothing else in them
// changed.
fn patch_path(gnu_root string, bin_dir string) ! {
	ours := os.abs_path(bin_dir)
	local_mk := os.join_path(gnu_root, 'tests/local.mk')
	content := os.read_file(local_mk)!
	mut lines := content.split_into_lines()
	mut patched := false
	for i, line in lines {
		trimmed := line.trim_space()
		if trimmed.starts_with('PATH=') {
			lines[i] = '\tPATH=\'${ours}\$(PATH_SEPARATOR)\'"\$\$PATH" \\'
			patched = true
		}
	}
	if !patched {
		return error('no PATH= line found in ${local_mk}')
	}
	os.write_file(local_mk, lines.join('\n'))!

	// Strip the prepend of GNU's build directory from every test, and rewrite
	// the two path variables the tests carry forward. This is done in V rather
	// than by shelling out to sed, because a sed replacement containing a
	// dollar sign and a file path needs quoting that V would rewrite.
	mut touched := 0
	for kind in ['*.sh', '*.pl'] {
		for f in os.glob('${gnu_root}/tests/**/${kind}') or { continue } {
			text := os.read_file(f) or { continue }
			if !text.contains('path_prepend_ ./src') && !text.contains(r'$abs_path_dir_')
				&& !text.contains(r'$abs_top_builddir/src') {
				continue
			}
			mut out := text.replace(' path_prepend_ ./src', '')
			out = out.replace(r'$abs_path_dir_', ours)
			out = out.replace(r'$abs_top_builddir/src', ours)
			os.write_file(f, out) or { continue }
			touched++
		}
	}
	_ = touched

	// Keep make from regenerating local.mk from Makefile.in and undoing this.
	touch_args := ['touch', os.join_path(gnu_root, 'tests/local.mk'), os.join_path(gnu_root,
		'tests/Makefile.in'), os.join_path(gnu_root, 'Makefile'), os.join_path(gnu_root,
		'Makefile.in')]
	touch_res := os.exec(touch_args)
	if touch_res.exit_code != 0 {
		return error('could not touch the makefiles')
	}
}

// built_programs returns the names of the executables in bin_dir, which is both
// the list $built_programs that GNU's require_built_ consults and the set of
// tools a run should cover. It is generated from what is actually there rather
// than from GNU's program list, because a tool we did not build must not be
// reported as covered.
fn built_programs(bin_dir string) string {
	mut names := []string{}
	entries := os.ls(bin_dir) or { return '' }
	for e in entries {
		full := os.join_path(bin_dir, e)
		if os.is_file(full) && os.is_executable(full) {
			names << e
		}
	}
	names.sort()
	return names.join(' ')
}

fn main() {
	mut cfg := Config{}
	for i := 1; i < os.args.len; i++ {
		a := os.args[i]
		match a {
			'--tag' {
				i++
				cfg.tag = os.args[i]
			}
			'--bin-dir' {
				i++
				cfg.bin_dir = os.args[i]
			}
			'--work-dir' {
				i++
				cfg.work_dir = os.args[i]
			}
			'--setup' {
				cfg.setup = true
			}
			'--run' {
				cfg.run = true
			}
			'--only' {
				i++
				cfg.only = os.args[i]
			}
			'--list', '-l' {
				cfg.list = true
			}
			'--jobs' {
				i++
				cfg.jobs = os.args[i].int()
			}
			'--help', '-h' {
				print(usage)
				exit(0)
			}
			else {
				eprintln('unknown option: ${a}')
				print(usage)
				exit(1)
			}
		}
	}

	ver := gnu_version(cfg.tag)
	gnu_root := os.join_path(cfg.work_dir, 'coreutils-${ver}')

	if cfg.list {
		eprintln('--list needs a built GNU tree and a make variable expansion;')
		eprintln('run make check with TESTS=tests/<tool>/*.sh directly instead')
		exit(1)
	}

	// Set up whenever the tree is not built yet, so that a plain run works
	// from a clean checkout. --setup forces it even when a build is present.
	if cfg.setup || !os.exists(os.join_path(gnu_root, 'src/cut')) {
		setup_gnu(gnu_root, cfg.tag, cfg.jobs) or {
			eprintln('setup failed: ${err}')
			exit(1)
		}
	}

	if !os.exists(os.join_path(gnu_root, 'src/cut')) {
		eprintln('GNU coreutils is not built at ${gnu_root}; run with --setup first')
		exit(1)
	}
	if !os.is_dir(cfg.bin_dir) {
		eprintln('no binaries at ${cfg.bin_dir}; run "make all" first')
		exit(1)
	}

	patch_path(gnu_root, cfg.bin_dir) or {
		eprintln('could not point the tests at ${cfg.bin_dir}: ${err}')
		exit(1)
	}

	println('> running GNU ${cfg.tag} test suite from ${gnu_root}')
	println('> against binaries in ${os.abs_path(cfg.bin_dir)}')

	// GNU's tests/local.mk lists its tests as `TESTS = $(all_tests)`, a make
	// variable rather than a list of paths, so there is no way to read the set
	// of tests out of the tree. The whole suite is run instead and the results
	// are filtered afterwards: a test for a tool that is not in bin/ has
	// nothing to invoke and fails with a missing-command error that says
	// nothing about our implementation.
	check_script := 'set -e
root="$1"; only="$2"; log="$3"
cd "$root"
rm -f tests/test-suite.log
if [ -n "$only" ]; then
  # A single tool is selected by its directory, which make expands itself.
  make check SUBDIRS=. TESTS="tests/$only/*.sh tests/$only/*.pl" VERBOSE=no gl_public_submodule_commit= > "$log" 2>&1 || true
else
  make check SUBDIRS=. VERBOSE=no gl_public_submodule_commit= > "$log" 2>&1 || true
fi
'
	code, out := run_shell(['bash', '-c', check_script, 'check', os.abs_path(gnu_root), cfg.only,
		os.join_path(os.abs_path(gnu_root), 'check.log')])
	if code != 0 {
		eprintln('make check failed:\n${out}')
		exit(1)
	}

	summarize(os.join_path(gnu_root, 'tests/test-suite.log'), cfg.bin_dir)
}

// summarize prints the verdict lines GNU's own test-suite.log records, which is
// the same source uutils' published numbers come from.
//
// The results are filtered to the tools present in bin_dir, because a test for
// a tool nobody built fails with a missing-command error that says nothing
// about this implementation. Those tests are counted separately rather than
// dropped, so the report never hides how much of the suite was measured.
fn summarize(log string, bin_dir string) {
	if !os.exists(log) {
		eprintln('no test-suite.log at ')
		exit(1)
	}
	content := os.read_file(log) or {
		eprintln('could not read : ')
		exit(1)
	}
	names := built_programs(bin_dir).split(' ')
	mut pass, fail, skip, error, unbuilt := 0, 0, 0, 0, 0
	mut failures := []string{}

	for line in content.split_into_lines() {
		verdict, rest := verdict_of(line) or { continue }
		// A verdict line looks like FAIL: tests/cut/cut.pl, so the second
		// path component is the tool the test exercises.
		parts := rest.trim_space().split('/')
		tool := if parts.len >= 2 { parts[1] } else { '' }
		measured := tool == '' || tool in names
		match verdict {
			'PASS' {
				if measured {
					pass++
				} else {
					unbuilt++
				}
			}
			'FAIL', 'ERROR' {
				if measured {
					if verdict == 'FAIL' {
						fail++
					} else {
						error++
					}
					failures << rest.trim_space()
				} else {
					unbuilt++
				}
			}
			'SKIP' {
				if measured {
					skip++
				}
			}
			else {}
		}
	}

	runnable := pass + fail
	rate := if runnable > 0 { f64(100 * pass) / f64(runnable) } else { f64(0) }
	println('')
	println('GNU test suite against ${os.abs_path(bin_dir)}')
	println('  pass     ${pass}')
	println('  fail     ${fail}')
	println('  error    ${error}')
	println('  skip     ${skip}')
	println('  not-run  ${unbuilt}   (tests for tools absent from bin_dir, excluded from the rate)')
	if runnable > 0 {
		println('  -------')
		println('  pass rate ${rate:.1f}%   ${pass} of ${runnable} runnable tests')
	}
	if failures.len > 0 {
		println('')
		println('failing tests:')
		for f in failures {
			println('  ${f}')
		}
	}
}

// verdict_of splits a test-suite.log verdict line into its verdict and the test
// path that follows. Lines that are not verdicts return none.
fn verdict_of(line string) ?(string, string) {
	for v in ['PASS', 'FAIL', 'SKIP', 'XFAIL', 'XPASS', 'ERROR'] {
		prefix := v + ':'
		if line.starts_with(prefix) {
			return v, line[prefix.len..]
		}
	}
	return none
}
