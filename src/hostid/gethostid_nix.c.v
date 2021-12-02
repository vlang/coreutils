#include <unistd.h>

fn C.gethostid() int

/*
** Get hostid from GNU libc
*/
fn hd_get_hostid() u32 {
	return u32(C.gethostid())
}
