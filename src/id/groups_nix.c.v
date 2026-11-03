module main

import os

#include <errno.h>
#include <unistd.h>

fn C.getgroups(int, &u32) int

fn current_process_groups(rgid int) ![]int {
	egid := os.getegid()
	if egid == -1 {
		return os.error_posix()
	}
	mut groups := [rgid]
	if egid != rgid {
		groups << egid
	}
	// The process group list can grow between the size query and the read.
	// Retry that race, but do not loop forever if it keeps changing.
	for _ in 0 .. 8 {
		count := C.getgroups(0, unsafe { nil })
		if count < 0 {
			return os.error_posix()
		}
		if count == 0 {
			return groups
		}
		mut gids := []u32{len: count}
		actual := unsafe { C.getgroups(count, &gids[0]) }
		if actual >= 0 {
			for gid in gids[..actual] {
				if int(gid) != rgid && int(gid) != egid {
					groups << int(gid)
				}
			}
			return groups
		}
		if C.errno != C.EINVAL {
			return os.error_posix()
		}
	}
	return os.error_posix(code: C.EINVAL)
}
