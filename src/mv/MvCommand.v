struct MvCommand {
	force               bool
	interactive         bool
	no_clobber          bool
	update              bool
	verbose             bool
	target_directory    string
	no_target_directory bool
}

fn (m MvCommand) run() {
	println(name)
}
