module main

import common
import common.pwd
import os

const app = common.CoreutilInfo{
	name:        'id'
	description: 'Print user and group information for each specified USER,
or (when USER omitted) for the current process.'
}

struct Settings {
mut:
	context bool
	group   bool
	groups  bool
	name    bool
	real    bool
	user    bool
	zero    bool
	users   []string
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	_ = fp.bool('', `a`, false, 'ignore, for compatibility with other versions')
	st.context = fp.bool('context', `Z`, false, 'print only the security context of the process')
	st.group = fp.bool('group', `g`, false, 'print only the effective group ID')
	st.groups = fp.bool('groups', `G`, false, 'print all group IDs')
	st.name = fp.bool('name', `n`, false, 'print a name instead of a number, for -ugG')
	st.real = fp.bool('real', `r`, false, 'print the real ID instead of the effective ID, with -ugG')
	st.user = fp.bool('user', `u`, false, 'print only the effective user ID')
	st.zero = fp.bool('zero', `z`, false, 'delimit entries with NUL characters, not whitespace; not permitted in default format')
	st.users = fp.remaining_parameters()
	if st.context {
		app.quit(message: '--context (-Z) works only on an SELinux-enabled kernel')
	}
	return st
}

fn id(settings Settings) ! {
	if settings.users.len == 0 {
		if settings.group {
			println(os.getegid())
		}
		if settings.user {
			println(os.geteuid())
		}
		if settings.groups {
			gids := pwd.get_groups() or { [] }
			for g in gids {
				print('${g} ')
			}
		}
	} else {
		// for user in settings.users {
		// 	if st.group {
		// 	}
		// }
	}
	/*
	uid := os.geteuid()
	if uid == -1 {
		app.quit(message: 'cannot get effective UID')
	}
	uid_name := pwd.get_name_for_uid(uid) or { '' }
	gid := os.getegid()
	if gid == -1 {
		app.quit(message: 'cannot get effective GID')
	}
	gid_name := pwd.get_name_for_gid(gid) or { '' }
	//print('uid=${uid}(${uid_name}) gid=${gid}(${gid_name})')
	// groups := pwd.get_groups()
	//print(pwd.get_groups() or { [] })
	gids := pwd.get_groups() or { [] }
	for g in gids {
		print('${pwd.get_name_for_gid(g)!} ')
	}
	*/
}

fn main() {
	id(args())!
}
