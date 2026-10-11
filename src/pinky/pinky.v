import common
import os
import time

const app_name = 'pinky'

struct Settings {
mut:
	all        bool // -b
	omit_home  bool // -h
	omit_plan  bool // -p
	omit_where bool // -w
	short_idle bool // -i
	quick      bool // -q
	lookup     bool // -l / --lookup
	operands   []string
}

struct Entry {
mut:
	name     string
	gecos    string
	line     string
	idle     i64
	has_idle bool
	time     i64
	where    string
	pid      int
}

fn main() {
	settings := args()
	// The listing follows the utmp file order, which is the order GNU prints.
	// Sorting it alphabetically would put "mr" before "root", and GNU shows
	// root first because that is how the records are stored.
	entries := utmp_entries(settings.operands, settings)
	render(entries, settings)
}

fn utmp_entries(files []string, settings Settings) []Entry {
	names := if files.len == 0 { [''] } else { files }
	mut entries := []Entry{}
	for name in names {
		cname := if name == '' { common.utmp_file_charptr } else { name.str }
		utmp_buf := user_processes(cname)
		unsafe {
			for u in utmp_buf {
				user := cstring_to_vstring(&u.ut_user[0])
				if user == '' {
					continue
				}
				mut e := Entry{
					name:  user
					line:  cstring_to_vstring(&u.ut_line[0])
					time:  i64(u.ut_tv.tv_sec)
					where: cstring_to_vstring(&u.ut_host[0])
					pid:   u.ut_pid
					gecos: gecos_for_name(user)
				}
				idle := idle_for(e.line)
				e.idle = idle
				e.has_idle = idle >= 0
				entries << e
			}
		}
	}
	return entries
}

// idle_for is the time since the terminal was last used, or -1 when the device
// cannot be stat'd.
fn idle_for(line string) i64 {
	if line == '' {
		return -1
	}
	st := os.lstat('/dev/${line}') or { return -1 }
	now := time.now().unix()
	if now <= st.atime {
		return 0
	}
	return now - st.atime
}

fn render(entries []Entry, settings Settings) {
	mut rows := []string{}
	rows << header_row(settings)
	for e in entries {
		// GNU prefixes the TTY with '*' to mark an active terminal, which is
		// the same marker last uses.
		tty := if e.line != '' { '*${e.line}' } else { '' }
		mut row := '${e.name:-8s} '
		if !settings.omit_home {
			row += '${e.gecos:-19s} '
		}
		row += '${tty:-8s} '
		if !settings.short_idle {
			row += '${format_idle(e)} '
		}
		row += format_time(e.time)
		if !settings.omit_where {
			row += ' ${e.where}'
		}
		rows << row
	}
	println(rows.join('\n'))
}

fn header_row(settings Settings) string {
	mut h := 'Login    '
	if !settings.omit_home {
		h += 'Name                 '
	}
	h += 'TTY      '
	if !settings.short_idle {
		h += 'Idle   '
	}
	h += 'When             '
	return h.trim_right(' ')
}

// format_idle is GNU's H:MM form, with ':' for an entry younger than a minute.
fn format_idle(e Entry) string {
	if !e.has_idle {
		return '     '
	}
	idle := e.idle
	if idle < 60 {
		return '     '
	}
	if idle < 60 * 60 {
		return '${idle / 60:02d}:${idle % 60:02d}'
	}
	if idle < 24 * 60 * 60 {
		return '${idle / 3600:02d}:${(idle % 3600) / 60:02d}'
	}
	days := idle / (24 * 60 * 60)
	return '${days + 1}d'
}

// format_time is GNU's "YYYY-MM-DD HH:MM".
fn format_time(t i64) string {
	d := time.unix(t)
	return '${d.year:04d}-${pad(int(d.month).str(), 2)}-${pad(int(d.day).str(), 2)} ${pad(int(d.hour).str(), 2)}:${pad(int(d.minute).str(), 2)}'
}

fn pad(s string, w int) string {
	if s.len >= w {
		return s
	}
	return ' '.repeat(w - s.len) + s
}

pub fn args() Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('A lightweight finger utility.')
	fp.allow_unknown_args()

	all := fp.bool('all', `b`, false, 'omit the user’s home directory and shell')
	omit_home := fp.bool('omit-home', `h`, false, 'do not print home directory')
	omit_plan := fp.bool('omit-plan', `p`, false, 'do not print the plan file')
	omit_where := fp.bool('omit-where', `w`, false, 'do not print the host name')
	short_idle := fp.bool('short-idle', `i`, false, 'short idle time')
	quick := fp.bool('quick', `q`, false, 'quick output')
	lookup := fp.bool('lookup', `l`, false, 'attempt to canonicalize hostnames')

	mut st := Settings{
		all:        all
		omit_home:  omit_home
		omit_plan:  omit_plan
		omit_where: omit_where
		short_idle: short_idle
		quick:      quick
		lookup:     lookup
	}
	st.operands = fp.remaining_parameters()
	return st
}
