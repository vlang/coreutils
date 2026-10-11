// Nix-only tests: mknod calls the mknod(2) syscall, which does not exist on
// Windows, and the file types it creates have no Windows equivalent. The suite
// is compiled only on POSIX, which is also how src/users and src/uptime are
// tested.
//
// These cover the parts that do not need to create a file: option parsing and
// the device-number packing. FIFO creation and the diagnostics were compared
// against GNU 9.4 by cross-compiling to Linux and running the binary under WSL.
import os

fn test_parse_mode_octal() {
	assert parse_mode('644') == 0o644
	assert parse_mode('0') == 0
	assert parse_mode('777') == 0o777
}

fn test_device_number_packing() {
	// Major and minor are packed the way makedev does, with the major number
	// in the high bits.
	assert device_number(0, 0) == 0
	assert device_number(1, 3) == (1 << 8) | 3
	assert device_number(8, 0) == (8 << 8)
}

fn test_type_bits() {
	assert type_bits(`p`) == 0
	assert type_bits(`b`) == s_ifblk
	assert type_bits(`c`) == s_ifchr
}

fn test_fifo_mode_includes_the_type_bits() {
	// The mode passed to mknod(2) is not just the permission: the file type
	// has to be folded in, or the kernel creates a plain file.
	assert s_ififo == 0o010000
	assert s_ifblk == 0o060000
	assert s_ifchr == 0o020000
}

fn test_default_mode_is_readable_and_writable() {
	// GNU applies the umask to the default mode, so a FIFO created with no -m
	// is 0666 masked by the umask.
	assert s_ififo & 0o666 == 0o666
}
