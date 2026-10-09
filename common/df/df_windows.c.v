module df

#include <windows.h>

fn C.GetLogicalDrives() u32
fn C.GetVolumeInformationA(voidptr, voidptr, u32, voidptr, voidptr, voidptr, &char, u32) u32
fn C.GetDiskFreeSpaceExA(voidptr, voidptr, &u64, &u64) u32

// inodes_supported is false on Windows: the APIs df needs report volume
// capacity but not the inode counts an -i listing is made of.
pub const inodes_supported = false

// list_mounts enumerates the ready drives of this machine and reports their
// capacities.
//
// The device name is the drive letter because that is the name a Windows user
// has for the volume, and the mount point is the same letter as a directory,
// because a Windows volume has one root rather than a POSIX mount path.
pub fn list_mounts() []MountInfo {
	mut out := []MountInfo{}
	mask := C.GetLogicalDrives()
	for i in 0 .. 26 {
		if (mask & (u32(1) << u32(i))) == 0 {
			continue
		}
		letter := u8(`A` + i)
		root := '${letter.ascii_str()}:\\'
		mut total := u64(0)
		mut avail := u64(0)
		if C.GetDiskFreeSpaceExA(&char(root.str), voidptr(unsafe { nil }), &total, &avail) == 0 {
			// Drives that report no sizes are removable bays and network
			// paths with no queryable capacity.
			continue
		}
		out << MountInfo{
			device:      root[..2]
			mounted:     root
			fstype:      volume_filesystem(root)
			total_bytes: total
			used_bytes:  total - avail
			free_bytes:  avail
		}
	}
	return out
}

// volume_filesystem returns the file-system name of a ready drive, or an
// empty string when the volume cannot be described.
fn volume_filesystem(root string) string {
	mut fs_buf := []u8{len: 64}
	ret := C.GetVolumeInformationA(&char(root.str), voidptr(unsafe { nil }), 0, voidptr(unsafe { nil }),
		voidptr(unsafe { nil }), voidptr(unsafe { nil }), voidptr(fs_buf.data), fs_buf.len)
	if ret == 0 {
		return ''
	}
	mut out := ''
	for c in fs_buf {
		if c == 0 {
			break
		}
		out += c.ascii_str()
	}
	return out
}
