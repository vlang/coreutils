import common

// The utmp and passwd bindings live here so the pure .v file never names a C
// type or calls C directly, which current V rejects in pure .v files. This is
// the same boundary src/users/users.c.v draws around read_utmp and
// src/nohup/nohup.c.v draws around C.dup2. The C.utmpx layout and the
// read_utmp helper come from common/readutmp_nix.c.v, and C.getpwnam from
// common/ids_nix.c.v.

// user_processes reads the utmp-format file and returns its login records in
// file order, which is the order GNU prints.
pub fn user_processes(file &char) []C.utmpx {
	mut utmp_buf := []C.utmpx{}
	common.read_utmp(file, mut utmp_buf, .user_process)
	return utmp_buf
}

// gecos_for_name reads the full name out of the passwd entry for a login
// name. A user with no passwd entry shows an empty GECOS field, as GNU does.
// The GECOS field is comma separated; the full name is the first part.
pub fn gecos_for_name(name string) string {
	pw := C.getpwnam(&char(name.str))
	if isnil(pw) {
		return ''
	}
	unsafe {
		return cstring_to_vstring(pw.pw_gecos).all_before(',')
	}
}
