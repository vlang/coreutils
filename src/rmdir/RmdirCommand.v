struct RmdirCommand {
	verbose bool
	// -v
	parents bool
	// -p
}
fn (r RmdirCommand) remove_dir(dir string) {
	if !r.verbose {
		os.rmdir(dir)
		return
	}
	
}
