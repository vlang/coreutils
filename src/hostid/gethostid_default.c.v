/*
** Get hostid on unsupported platforms
*/
fn hd_get_hostid() u32 {
	eprintln('Unsupported platform')
	return 0
}
