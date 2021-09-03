import os // v has a bug that you can't use args

const (
	ignore_dirs = []string{}
)

vargs := if os.args.len > 1 { os.args[1..] } else { []string{} }

curdir := getwd()
chdir('src') ?

dirs := ls('.') ?.filter(is_dir(it))

if !exists('$curdir/bin') {
	mkdir('$curdir/bin') ?
}

for dir in dirs {
	if dir in ignore_dirs {
		continue
	}
	if !ls(dir) ?.any(it.ends_with('.v')) {
		continue
	}

	// TODO: don't build something if it is already built

	mut final_args := '-Wimpure-v'
	for arg in vargs {
		final_args += ' ' + arg
	}
	println('compiling ${dir}...')
	cmd := 'v $final_args -o $curdir/bin/$dir ./$dir'
	execute_or_panic(cmd)
}

chdir(curdir) ?
