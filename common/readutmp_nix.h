// The one glibc extension this module calls that <utmpx.h> only declares when
// _GNU_SOURCE is defined. The prototype is spelled out here so that the module
// needs no feature macros: asking for _GNU_SOURCE project wide would expose
// declarations that collide with the V functions this repository shares names
// with, `basename`, `tee` and `canonicalize` among them.
#ifndef COMMON_READUTMP_NIX_H
#define COMMON_READUTMP_NIX_H

#ifndef _GNU_SOURCE
int utmpxname(const char *file);
#endif

#endif
