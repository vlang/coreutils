module mknod

import common

pub const s_ififo = u32(0o010000)
pub const s_ifblk = u32(0o060000)
pub const s_ifchr = u32(0o020000)

pub fn type_bits(kind u8) u32 {
	return match kind {
		`b` { s_ifblk }
		`c` { s_ifchr }
		else { u32(0) }
	}
}

pub fn device_number(major int, minor int) u64 {
	// Pack major and minor the way makedev does: major in the high bits.
	return (u64(major) << 8) | u64(minor)
}

pub fn parse_mode(s string) u32 {
	if s == '' {
		common.exit_with_error_message('mknod', 'invalid mode')
	}
	mut n := u32(0)
	for c in s.bytes() {
		if c < `0` || c > `7` {
			common.exit_with_error_message('mknod', "invalid mode '${s}'")
		}
		n = n * 8 + u32(c - `0`)
	}
	return n
}
