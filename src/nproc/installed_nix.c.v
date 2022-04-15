$if linux || macos || solaris {
	#include <unistd.h>
}

/*
** Installed_processors
** Get the number of installed processor
*/
fn nb_configured_processors() int {
	$if linux || macos || solaris {
		return int(C.sysconf(C._SC_NPROCESSORS_CONF))
	}
	return 1
}
