import os // v has a bug that you can't use args

const (
	ignore_dirs = []string{}
)

vargs := if os.args.len > 1 { os.args[1..] } else { []string{} }

dirs := ls('.') ?.filter(is_dir(it))

if !exists('bin') {
	mkdir('bin') ?
}

for dir in dirs {
	if dir in ignore_dirs {
		continue
	}
	if !ls(dir) ?.any(it.ends_with('.v')) {
		continue
	}

	// TODO: don't build something if it is already built

	mut final_args := ''
	for arg in vargs {
		final_args += arg + ' '
	}
	println('compiling ${dir}...')
	cmd := 'v $final_args-o bin/$dir $dir'
	execute_or_panic(cmd)
}
