#!/bin/env v

import os // v has a bug that you can't use args

const (
	ignore_dirs = $if windows {
		[
			// avoid *nix-dependent utils
			'nohup',
			// avoid utmp-dependent utils (WinOS has no utmp support)
			'uptime',
			'users',
			'who',
		]
	} $else {
		[]string{}
	}
)

vargs := if os.args.len > 1 { os.args[1..] } else { []string{} }

curdir := getwd()
chdir('src')!

dirs := ls('.')!.filter(is_dir(it))

if !exists('${curdir}/bin') {
	mkdir('${curdir}/bin')!
}

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
		modification_time << os.file_last_mod_unix('${dir}/${src_file}')
	}

	// Check if the binary exists and is newer than the source files
	// If it is, skip it
	if exists('${curdir}/bin/${dir}') {
		bin_mod_time := os.file_last_mod_unix('${curdir}/bin/${dir}')
		// If the binary is newer than the source files, skip it
		if modification_time.filter(it < bin_mod_time).len == modification_time.len {
			continue
		}
	}

	mut final_args := '-Wimpure-v'
	for arg in vargs {
		final_args += ' ' + arg
	}
	println('compiling ${dir}...')
	cmd := @VEXE + ' ${final_args} -o ${curdir}/bin/${dir} ./${dir}'
	execute_or_panic(cmd)
}

chdir(curdir)!
