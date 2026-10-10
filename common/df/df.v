module df

// Block-size output mode. -i replaces the size columns with inode columns
// and overrides -k/-B, which is why it is a separate mode instead of a
// flag tested alongside the others.
pub enum Mode {
	human
	si_human
	kibibytes
	mebibytes
	gibibytes
	blocks
	inodes
}

pub struct MountInfo {
pub mut:
	device      string
	mounted     string
	fstype      string
	total_bytes u64
	used_bytes  u64
	free_bytes  u64
}

pub struct Settings {
pub mut:
	mode          Mode = .kibibytes
	block_size    int  = 1024
	inodes        bool
	all           bool
	show_type     bool
	total         bool
	local         bool
	exclude_types []string
	include_types []string
	operands      []string
}

// network_types are the file-system types --local excludes. On POSIX these
// are the network mounts /proc/mounts reports; on Windows every volume is
// local, so nothing is excluded there.
const network_types = ['nfs', 'nfs4', 'cifs', 'smbfs', 'smb3', 'afs', 'ncpfs', 'lustre', 'fuse.sshfs',
	'sshfs', 'gfs', 'gfs2', 'glusterfs', 'ceph', '9p', 'davfs', 'webdav']

// report returns the text main should print, or a failure when the platform
// cannot honour the requested mode.
pub fn report(set Settings) !string {
	if set.inodes && !inodes_supported {
		// Windows exposes no per-volume inode counts, so the columns would
		// have to be invented. GNU on POSIX reports them from statvfs.
		return error("doesn't support -i option")
	}
	return render_table(collect_mounts(set), set)
}

// collect_mounts turns the raw per-platform volume list into what the table
// should show. The filtering lives here rather than in the platform code so
// it is covered by the tests.
pub fn collect_mounts(set Settings) []MountInfo {
	mut mounts := list_mounts()

	// Volumes the platform cannot size have no usable numbers. GNU hides
	// these unless --all is given, because a row of zeros is never the
	// information the reader came for.
	if !set.all {
		mounts = mounts.filter(it.total_bytes > 0)
	}

	if set.include_types.len > 0 {
		mounts = mounts.filter(it.fstype in set.include_types)
	}
	if set.exclude_types.len > 0 {
		mounts = mounts.filter(it.fstype !in set.exclude_types)
	}
	if set.local {
		mounts = mounts.filter(it.fstype !in network_types)
	}

	if set.operands.len == 0 {
		return mounts
	}

	// With operands, only the file systems holding those paths are listed,
	// each at most once and in the order they were first named.
	mut matched := []MountInfo{}
	mut seen := []string{}
	for op in set.operands {
		for m in mounts {
			if m.device in seen {
				continue
			}
			if holds_path(m, op) {
				seen << m.device
				matched << m
				break
			}
		}
	}
	return matched
}

fn holds_path(mount MountInfo, path string) bool {
	return mount.mounted != '' && is_same_location(mount.mounted, path)
}

fn is_same_location(mounted string, path string) bool {
	mut target := path
	// '..' and symlinks would both change which volume a name resolves to;
	// both are dropped rather than resolved, so the comparison stays a pure
	// string operation and a non-existent path cannot be turned into one.
	for target.len > 1 && (target.ends_with('/') || target.ends_with('\\')) {
		target = target[..target.len - 1]
	}
	if mounted == target {
		return true
	}
	return mounted.len <= target.len && target[..mounted.len] == mounted
		&& (mounted.len == 1 || is_separator(target[mounted.len], mounted[0]))
}

fn is_separator(c u8, first u8) bool {
	if first == `\\` || first == `/` {
		return c == `/` || c == `\\`
	}
	return c == `\\`
}

// render_table is the whole presentation layer. It returns the text rather
// than printing it so the column layout can be asserted on without capturing
// standard output.
pub fn render_table(mounts []MountInfo, set Settings) string {
	mut rows := []MountInfo{}
	for m in mounts {
		rows << m
	}
	if set.total {
		mut t := MountInfo{
			device:  'total'
			mounted: '-'
			fstype:  '-'
		}
		for m in mounts {
			t.total_bytes += m.total_bytes
			t.used_bytes += m.used_bytes
			t.free_bytes += m.free_bytes
		}
		rows << t
	}

	mut labels_size := if set.inodes { 'Inodes' } else { '1K-blocks' }
	mut labels_used := if set.inodes { 'IUsed' } else { 'Used' }
	mut labels_avail := if set.inodes { 'IFree' } else { 'Available' }
	mut labels_pct := if set.inodes { 'IUse%' } else { 'Use%' }

	match set.mode {
		.human, .si_human {
			labels_size = 'Size'
			labels_avail = 'Avail'
		}
		.mebibytes {
			labels_size = '1M-blocks'
		}
		.gibibytes {
			labels_size = '1G-blocks'
		}
		.blocks {
			labels_size = '${set.block_size}-blocks'
		}
		else {}
	}

	mut fields := [][]string{}
	for r in rows {
		fields << format_row(r, set).split('\t')
	}

	// Column widths are the widest of the header, the data and a per-column
	// minimum GNU reserves, so a value wider than its header pushes the
	// header out to match. Measured against GNU 9.4:
	//	Filesystem  minimum 14, then the widest device name
	//	Type         minimum 4, right-justified
	//	Size/Used    minimum 5 even when the header and data are shorter
	//	Use%         minimum 4
	// The last column is left-justified and not padded, so GNU prints no
	// trailing spaces when a mount point is short.
	mut widths := [14, 5, 5, labels_avail.len, labels_pct.len, 0, 4]
	headers := ['Filesystem', labels_size, labels_used, labels_avail, labels_pct, 'Mounted on',
		'Type']
	for i, h in headers {
		if h.len > widths[i] {
			widths[i] = h.len
		}
	}
	for f in fields {
		for i in 0 .. 7 {
			if f[i].len > widths[i] {
				widths[i] = f[i].len
			}
		}
	}

	// The type column carries its own leading space so a line reads the same
	// with and without --print-type.
	type_header := if set.show_type { ' ' + rjust('Type', widths[6]) } else { '' }

	mut lines := []string{}
	lines << '${ljust('Filesystem', widths[0])}${type_header} ${rjust(labels_size, widths[1])} ${rjust(labels_used, widths[2])} ${rjust(labels_avail, widths[3])} ${rjust(labels_pct, widths[4])} Mounted on'

	for f in fields {
		type_col := if set.show_type { ' ' + rjust(f[6], widths[6]) } else { '' }
		lines << '${ljust(f[0], widths[0])}${type_col} ${rjust(f[1], widths[1])} ${rjust(f[2], widths[2])} ${rjust(f[3], widths[3])} ${rjust(f[4], widths[4])} ${f[5]}'
	}
	return lines.join('\n')
}

// format_row returns the six textual columns plus the file-system type,
// tab-separated. A tab is the delimiter because a device name, a mount point
// or a type string may contain spaces; render_table splits it back apart.
fn format_row(m MountInfo, set Settings) string {
	mut size_str := ''
	mut used_str := ''
	mut avail_str := ''

	if set.inodes {
		size_str = m.total_bytes.str()
		used_str = m.used_bytes.str()
		avail_str = m.free_bytes.str()
	} else {
		size_str = format_size(m.total_bytes, set)
		used_str = format_size(m.used_bytes, set)
		avail_str = format_size(m.free_bytes, set)
	}

	// A volume whose total size is unreadable prints '-' rather than a
	// percentage computed from zero.
	pct_str := if m.total_bytes == 0 {
		'-'
	} else {
		usage_pct(m.used_bytes, m.total_bytes)
	}

	return '${m.device}\t${size_str}\t${used_str}\t${avail_str}\t${pct_str}\t${m.mounted}\t${m.fstype}'
}

fn usage_pct(used u64, total u64) string {
	return '${(used * 100 + total / 2) / total}%'
}

pub fn format_size(bytes u64, set Settings) string {
	match set.mode {
		.human, .si_human {
			return human_readable(bytes, set.mode == .si_human)
		}
		.blocks {
			if set.block_size <= 0 {
				return bytes.str()
			}
			return (bytes / u64(set.block_size)).str()
		}
		else {
			mut div := u64(1024)
			match set.mode {
				.mebibytes { div = u64(1024) * 1024 }
				.gibibytes { div = u64(1024) * 1024 * 1024 }
				else {}
			}
			return (bytes / div).str()
		}
	}
}

// human_readable prints at most four significant characters: one decimal
// below 10 and none at or above it. si selects powers of 1000 over 1024.
pub fn human_readable(bytes u64, si bool) string {
	base := if si { u64(1000) } else { u64(1024) }
	// --si keeps the SI 'k' but the conventional M, G, T for the rest;
	// --human-readable uses K for the first unit. Measured at GNU 9.4:
	//	--si  132k 78M 1.1T
	//	-h    128K 74M 1007G
	units := if si { 'kMGTPEZY' } else { 'KMGTPEZY' }

	mut value := f64(bytes)
	mut idx := 0
	for idx < units.len && value >= f64(base) {
		value /= f64(base)
		idx++
	}

	mut body := if idx > 0 && value < 10.0 {
		'${value:.1f}'
	} else {
		'${value:.0f}'
	}
	if idx > 0 {
		body += units[idx - 1].ascii_str()
	}
	return body
}

fn rjust(s string, w int) string {
	if s.len >= w {
		return s
	}
	return ' '.repeat(w - s.len) + s
}

fn ljust(s string, w int) string {
	if s.len >= w {
		return s
	}
	return s + ' '.repeat(w - s.len)
}
