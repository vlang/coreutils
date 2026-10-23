// runcon and chcon share the SELinux context parser, because the syntax is
// shared. On a kernel without SELinux both fail the same way, which is also
// where this measured.
module selinux

// Context is a parsed SELinux security context, i.e. the
// user:role:type[:level] that -u, -r, -t and -l modify independently.
pub struct Context {
pub mut:
	user  string
	role  string
	ctype string
	level string
}

// parse_context splits a context into its four fields. Missing fields stay
// empty, which distinguishes "not given" from "given as empty" — the difference
// between leaving a field alone and clearing it.
pub fn parse_context(s string) Context {
	mut parts := s.split(':')
	mut c := Context{}
	if parts.len > 0 {
		c.user = parts[0]
	}
	if parts.len > 1 {
		c.role = parts[1]
	}
	if parts.len > 2 {
		c.ctype = parts[2]
	}
	if parts.len > 3 {
		c.level = parts[3]
	}
	return c
}
