module df

import os

// inodes_supported is true on POSIX: statvfs reports a per-file-system inode
// count.
pub const inodes_supported = true

// list_mounts reads the mount table and asks the kernel for each volume's
// usage. /proc/mounts is used in preference to getmntent because it is the
// table the kernel itself maintains, so it lists the same mounts df lists.
pub fn list_mounts() []MountInfo {
	content := os.read_file('/proc/mounts') or { return []MountInfo{} }
	mut out := []MountInfo{}

	for line in content.split_into_lines() {
		if line == '' || line.starts_with('#') {
			continue
		}
		// The kernel escapes any space, tab, newline or backslash in the
		// device, mount point and type fields as an octal escape, so the
		// line can be split on whitespace unconditionally.
		fields := line.split(' ')
		if fields.len < 3 {
			continue
		}
		device := unescape_mount_field(fields[0])
		mounted := unescape_mount_field(fields[1])
		fstype := unescape_mount_field(fields[2])

		// A mount the kernel will not size reports zeroes, which the
		// filtering step hides unless --all is given.
		usage := os.disk_usage(mounted) or { os.DiskUsage{} }

		out << MountInfo{
			device:      device
			mounted:     mounted
			fstype:      fstype
			total_bytes: usage.total
			used_bytes:  usage.used
			free_bytes:  usage.available
		}
	}
	return out
}

// unescape_mount_field decodes the octal escapes the kernel writes for the
// four characters that cannot appear literally in /proc/mounts.
fn unescape_mount_field(s string) string {
	if !s.contains('\\') {
		return s
	}
	mut out := []u8{}
	mut i := 0
	for i < s.len {
		c := s[i]
		if c == `\\` && i + 3 < s.len && s[i + 1] >= `0` && s[i + 1] <= `7`
			&& s[i + 2] >= `0` && s[i + 2] <= `7` && s[i + 3] >= `0` && s[i + 3] <= `7` {
			val := (int(s[i + 1]) - int(`0`)) * 64 + (int(s[i + 2]) - int(`0`)) * 8 +
				(int(s[i + 3]) - int(`0`))
			out << u8(val)
			i += 4
		} else {
			out << c
			i++
		}
	}
	return out.bytestr()
}
