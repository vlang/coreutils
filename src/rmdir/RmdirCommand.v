import os

struct RmdirCommand {
	verbose bool
	// -v
	parents bool
	// -p
}

fn (r RmdirCommand) remove_dir(dir string) {
	if r.verbose {
		println("rmdir: removing directory, '$dir'")
	}
	os.rmdir(dir) or { eprintln(err.msg) }
	if r.parents {
		mut temp := if dir[dir.len - 1] == `/` { dir[0..dir.len - 1] } else { dir }
		temp = os.dir(temp)
		for temp != '' && temp != '/' && temp != '.' {
			println(os.exists(temp))
			os.rmdir(dir) or { eprintln('$temp: $err.msg') }
			temp = os.dir(temp)
		}
	}
}
