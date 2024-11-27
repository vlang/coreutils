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
	context   bool
	group     bool
	groups    bool
	name      bool
	real      bool
	user      bool
	zero      bool
	users     []string
	field_sep string
	line_sep  string
}

fn are_multiple_set(bools ...bool) bool {
	mut one_set := false
	for b in bools {
		if b {
			if !one_set {
				one_set = true
			} else {
				return true
			}
		}
	}
	return false
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
	if are_multiple_set(st.context, st.group, st.groups, st.user) {
		app.quit(message: 'cannot print "only" of more than one choice')
	}
	if !st.group && !st.user && !st.groups {
		if st.name {
			app.quit(message: 'cannot print only names or real IDs in default format')
		}
		if st.real {
			app.quit(message: 'cannot print only names or real IDs in default format')
		}
	}
	st.field_sep = if st.zero { '\0' } else { ' ' }
	st.line_sep = if st.zero { '\0' } else { '\n' }
	return st
}

fn get_group_descr(gid int) string {
	return '${gid}(${pwd.get_name_for_gid(gid) or { '' }})'
}

fn print_gid(gid int, print_name bool, line_sep string) ! {
	if !print_name {
		print(gid)
	} else {
		print(pwd.get_name_for_gid(gid)!)
	}
}

fn print_uid(uid int, print_name bool, line_sep string) ! {
	if !print_name {
		print(uid)
	} else {
		print(pwd.get_name_for_uid(uid)!)
	}
}

fn print_groups(gids []int, print_name bool, line_sep string, field_sep string) ! {
	if !print_name {
		print(gids.map(it.str()).join(field_sep))
	} else {
		print(gids.map(pwd.get_name_for_gid(it)!).join(field_sep))
	}
}

fn print_info(uid int, gid int, settings Settings) ! {
	if settings.group {
		print_gid(gid, settings.name, settings.line_sep)!
	}
	if settings.user {
		print_uid(uid, settings.name, settings.line_sep)!
	}
	if settings.groups {
		gids := pwd.get_groups(pwd.get_name_for_uid(uid)!)!
		print_groups(gids, settings.name, settings.line_sep, settings.field_sep)!
	}
	if !settings.group && !settings.user && !settings.groups {
		mut buffer := []string{}
		uid_name := pwd.get_name_for_uid(uid)!
		gid_name := pwd.get_name_for_gid(gid)!
		buffer << 'uid=${uid}(${uid_name})'
		buffer << 'gid=${gid}(${gid_name})'
		gids := pwd.get_groups(uid_name)!
		buffer << 'groups=${gids.map(get_group_descr).join(',')}'
		print(buffer.join(settings.field_sep))
	}
}

fn id(settings Settings) !int {
	mut exit_code := 0
	if settings.users.len == 0 {
		ruid := os.getuid()
		if ruid == -1 {
			app.quit(message: 'cannot get real UID')
		}
		rgid := os.getgid()
		if rgid == -1 {
			app.quit(message: 'cannot get real GID')
		}
		if settings.real {
			print_info(ruid, rgid, settings)!
		} else {
			// We only need effective UID and GID if -r is not set
			euid := os.geteuid()
			if euid == -1 {
				app.quit(message: 'cannot get effective UID')
			}
			egid := os.getegid()
			if egid == -1 {
				app.quit(message: 'cannot get effective GID')
			}
			if settings.group {
				print_gid(egid, settings.name, settings.line_sep)!
			}
			if settings.user {
				print_uid(euid, settings.name, settings.line_sep)!
			}
			if settings.groups {
				gids := pwd.get_effective_groups()!
				print_groups(gids, settings.name, settings.line_sep, settings.field_sep)!
			}
			if !settings.group && !settings.user && !settings.groups {
				mut buffer := []string{}
				ruid_name := pwd.get_name_for_uid(ruid)!
				rgid_name := pwd.get_name_for_gid(rgid)!
				buffer << 'uid=${ruid}(${ruid_name})'
				buffer << 'gid=${rgid}(${rgid_name})'
				if ruid != euid {
					euid_name := pwd.get_name_for_uid(euid)!
					buffer << 'euid=${euid}(${euid_name})'
				}
				if rgid != egid {
					egid_name := pwd.get_name_for_gid(egid)!
					buffer << 'egid=${egid}(${egid_name})'
				}
				gids := pwd.get_effective_groups()!
				buffer << 'groups=${gids.map(get_group_descr).join(',')}'
				print(buffer.join(settings.field_sep))
			}
		}
		print(settings.line_sep)
	} else {
		for user in settings.users {
			u := pwd.get_userinfo_for_name(user) or {
				app.eprintln("'${user}': no such user")
				exit_code = 1
				continue
			}
			print_info(u.uid, u.gid, settings)!
			print(settings.line_sep)
			if settings.zero && settings.groups && settings.users.len > 1 {
				// If we zero-delimit the group list only, add an extra one to
				// indicate end of record (followin GNU coreutils example)
				print(settings.line_sep)
			}
		}
	}

	return exit_code
}

fn main() {
	exit(id(args()) or { common.err_programming_error })
}
