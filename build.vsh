#!/bin/env v

import time
import runtime
import flag
import os

struct Config {
	jobs int @[long: cpus; short: 'j']
}

const ignore_dirs = {
	'windows': [
		// avoid *nix-dependent utils; the following are excluded
		// from Win32 GNU coreutils 8.32:
		'arch',
		'chgrp',
		'chmod',
		'chown',
		'chroot',
		'df',
		'dir',
		'groups',
		'hostid',
		'hostname',
		'id',
		'install',
		'ls',
		'nice',
		'pinky',
		'stat',
		'stdbuf',
		'stty',
		'sync',
		'timeout',
		'tty',
		'vdir',
		// The following are excluded because utmp-dependent
		// (and also not part of Win32 GNU coreutils):
		'uptime',
		'users',
		'who',
		// TODO: nohup is included in Win32 version
		'nohup',
	]
	'macos':   ['stat', 'sync', 'uptime']
}[user_os()] or { [] }

// multicall_tools are the tools implemented inside the single `coreutils`
// binary rather than as their own executable. This list has to stay in step with
// the tools map in src/multicall/main.v: a name here that is missing there is
// linked to a binary that does not implement it.
//
// A tool is in this list because it has been converted from `module main` with
// its own `fn main()` to a module exposing `pub fn run(args []string) int`, which
// is what makes it importable by the multicall. The conversion is what lets both
// build styles share one implementation of a tool, instead of keeping two copies
// of it in step.
//
// `false` is deliberately not here: V rejects `module false` because `false` is
// a keyword and a module name has to match its directory, so the tool cannot be
// imported into a multicall without renaming its directory.
const multicall_tools = ['arch', 'hostid', 'pwd', 'true', 'tty', 'whoami', 'yes']

// build_multicall compiles the single binary that implements the converted
// tools, then links another name to it for each of them. Hard links rather than
// copies, so there is one executable on disk and a rebuild updates every tool at
// once. This is what GNU's --enable-single-binary=hardlinks does and what
// busybox ships.
fn build_multicall(curdir string, vargs []string) ! {
	exe_name := if user_os() == 'windows' { 'coreutils.exe' } else { 'coreutils' }
	mc_exe := '${curdir}/bin/${exe_name}'
	if !exists(mc_exe) {
		mut cmd := [@VEXE, '-Wimpure-v']
		cmd << vargs
		cmd << ['-o', mc_exe, './multicall']
		println('> building the multicall binary ${exe_name}')
		os.exec_or_panic(cmd)
	}
	for tool in multicall_tools {
		link_name := if user_os() == 'windows' { '${tool}.exe' } else { tool }
		link_path := '${curdir}/bin/${link_name}'
		rm(link_path) or {}
		// A hard link on the same filesystem, falling back to a copy where the
		// platform or filesystem does not allow one.
		if os.link(mc_exe, link_path) != none {
			cp(mc_exe, link_path)!
		}
	}
	println('> Linked ${multicall_tools.len} tools to ${exe_name}: ${multicall_tools.join(', ')}')
}

unbuffer_stdout()

config, remaining := flag.to_struct[Config](os.args, skip: 1)!
mut jobs := if config.jobs > 0 { config.jobs } else { runtime.nr_cpus() }
mut vargs := remaining.clone()
println('Using ${jobs} parallel jobs')

curdir := getwd()
chdir('src')!

dirs := ls('.')!.filter(is_dir(it)).sorted()

if !exists('${curdir}/bin') {
	mkdir('${curdir}/bin')!
}

sw_total := time.new_stopwatch()
mut compiled := 0
mut already_compiled := 0
mut dirs_to_compile := []string{}

for dir in dirs {
	if dir in ignore_dirs {
		continue
	}
	// A tool implemented inside the multicall binary has no main of its own, so
	// compiling it on its own would fail. It is handled after the individually
	// compiled tools, by linking its name to the multicall binary.
	if dir in multicall_tools {
		continue
	}
	if !ls(dir)!.any(it.ends_with('.v')) {
		continue
	}

	// Get all of the of v files in the directory and get unix modifed time
	mut modification_time := []i64{}
	for src_file in ls(dir)!.filter(it.ends_with('.v')) {
		modification_time << file_last_mod_unix('${dir}/${src_file}')
	}

	// Check if the binary exists and is newer than the source files
	// If it is, skip it
	if exists('${curdir}/bin/${dir}') {
		bin_mod_time := file_last_mod_unix('${curdir}/bin/${dir}')
		// If the binary is newer than the source files, skip it
		if modification_time.filter(it < bin_mod_time).len == modification_time.len {
			already_compiled++
			continue
		}
	}

	dirs_to_compile << dir
}

// Now compile in parallel
ch := chan bool{cap: jobs}
results_ch := chan bool{cap: dirs_to_compile.len}
print_ch := chan string{cap: 100}

// Start printer thread, avoiding garbled text when building
spawn fn [print_ch] () {
	for {
		msg := <-print_ch or { break }
		print(msg)
	}
}()

for dir in dirs_to_compile {
	// Acquire the current slot
	ch <- true
	spawn fn [ch, results_ch, dir, curdir, vargs, print_ch] () {
		defer {
			results_ch <- true
			// Released
			_ := <-ch
		}
		// `os.exec` takes an argument array rather than a command string, so the
		// word splitting happens here instead of in a shell. Each argument is passed
		// as it is, which is why a path with a space in it needs no quoting.
		mut cmd := [@VEXE, '-Wimpure-v']
		cmd << vargs
		cmd << ['-o', '${curdir}/bin/${dir}', './${dir}']
		sw := time.new_stopwatch()
		os.exec_or_panic(cmd)
		print_ch <- 'compiling ${dir:-20s}... took ${sw.elapsed().milliseconds()}ms .\n'
	}()
}

// Wait for all compilations to finish
for _ in 0 .. dirs_to_compile.len {
	_ := <-results_ch
}

print_ch.close()
compiled = dirs_to_compile.len
println('> Compiled: ${compiled:3} tools in ${sw_total.elapsed().milliseconds()}ms. Already compiled and skipped: ${already_compiled} . All folders: ${dirs.len} .')
chdir(curdir)!

if multicall_tools.len > 0 {
	build_multicall(curdir, vargs) or { panic(err) }
}
