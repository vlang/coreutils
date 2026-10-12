module whoami

import os

#include <pwd.h>

struct C.passwd {
	pw_name &char
}

fn C.getpwuid(uid int) &C.passwd

fn whoami() !string {
	uid := os.geteuid()
