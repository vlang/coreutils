fn filter(entries []Entry, options Options) []Entry {
	return match true {
		// vfmt off
		options.only_dirs  { entries.clone().filter(it.dir) }
		options.only_files { entries.clone().filter(it.file) }
		else 		   { entries }
		// vfmt on
	}
}
