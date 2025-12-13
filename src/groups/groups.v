module main

import os
import common
import common.pwd

const app = common.CoreutilInfo{
	name:        'groups'
	description: 'Print group memberships for each USERNAME or, if no USERNAME is specified, for
the current process (which may differ if the groups database has changed).'
}

struct Settings {
mut:
	users []string
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	st.users = fp.remaining_parameters()
	return st
}

fn get_group_name(gid int) string {
	return pwd.get_name_for_gid(gid) or { '' }
}

fn get_group_list(username string) !string {
	_ := pwd.get_userinfo_for_name(username) or {
		app.eprintln("'${username}': no such user")
		return ''
	}
	groups := pwd.get_groups(username)!
	return groups.map(get_group_name).join(' ')
}

fn get_effective_group_list() !string {
	groups := pwd.get_effective_groups()!
	return groups.map(get_group_name).join(' ')
}

fn groups(settings Settings) !int {
	mut exit_code := 0
	if settings.users == [] {
		println(get_effective_group_list()!)
	} else {
		for user in settings.users {
			group_list := get_group_list(user)!
			if group_list != '' {
				println('${user} : ${group_list}')
			} else {
				exit_code = 1
			}
		}
	}
	return exit_code
}

fn main() {
	exit(groups(args()) or { common.err_programming_error })
}
