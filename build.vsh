#!/bin/env v

import time

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

unbuffer_stdout()

dump(user_os())
dump(ignore_dirs)

args := arguments()
vargs := if args.len > 1 { args[1..] } else { [] }
dump(vargs)

curdir := getwd()
chdir('src')!

dirs := ls('.')!.filter(is_dir(it)).sorted()

if !exists('${curdir}/bin') {
	mkdir('${curdir}/bin')!
}

sw_total := time.new_stopwatch()
mut compiled := 0
mut already_compiled := 0
for dir in dirs {
	if dir in ignore_dirs {
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

	mut final_args := '-Wimpure-v'
	for arg in vargs {
		final_args += ' ' + arg
	}
	print('compiling ${dir:-20s}...')
	cmd := @VEXE + ' ${final_args} -o ${curdir}/bin/${dir} ./${dir}'
	sw := time.new_stopwatch()
	execute_or_panic(cmd)
	println(' took ${sw.elapsed().milliseconds()}ms .')
	compiled++
}
println('> Compiled: ${compiled:3} tools in ${sw_total.elapsed().milliseconds()}ms. Already compiled and skipped: ${already_compiled} . All folders: ${dirs.len} .')
chdir(curdir)!
