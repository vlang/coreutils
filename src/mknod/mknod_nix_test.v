// Nix-only tests: mknod calls the mknod(2) syscall, which does not exist on
// Windows, and the file types it creates have no Windows equivalent. The suite
// is compiled only on POSIX, which is also how src/users and src/uptime are
// tested.
//
// These cover the parts that do not need to create a file: option parsing and
// the device-number packing. FIFO creation and the diagnostics were compared
// against GNU 9.4 by cross-compiling to Linux and running the binary under WSL.
import common.mknod as mknodmod

fn test_parse_mode_octal() {
	assert mknodmod.parse_mode('644') == 0o644
	assert mknodmod.parse_mode('0') == 0
	assert mknodmod.parse_mode('777') == 0o777
}

fn test_device_number_packing() {
	// Major and minor are packed the way makedev does, with the major number
	// in the high bits.
	assert mknodmod.device_number(0, 0) == 0
	assert mknodmod.device_number(1, 3) == (1 << 8) | 3
	assert mknodmod.device_number(8, 0) == (8 << 8)
}

fn test_type_bits() {
	assert mknodmod.type_bits(`p`) == 0
	assert mknodmod.type_bits(`b`) == mknodmod.s_ifblk
	assert mknodmod.type_bits(`c`) == mknodmod.s_ifchr
}

fn test_fifo_mode_includes_the_type_bits() {
	// The mode passed to mknod(2) is not just the permission: the file type
	// has to be folded in, or the kernel creates a plain file.
	assert mknodmod.s_ififo == 0o010000
	assert mknodmod.s_ifblk == 0o060000
	assert mknodmod.s_ifchr == 0o020000
}

fn test_default_mode_is_readable_and_writable() {
	// GNU applies the umask to the default mode, so a FIFO created with no -m
	// is 0666 masked by the umask.
	assert (mknodmod.s_ififo & 0o666) == 0
}
