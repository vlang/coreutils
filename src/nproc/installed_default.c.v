import runtime

/*
** Installed_processors
** Get the number of installed processor
*/
fn nb_configured_processors() int {
	// Fallback
	return runtime.nr_cpus()
}
