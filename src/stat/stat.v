module main

import common
import common.pwd
import io
import os
import strconv
import time

const app = common.CoreutilInfo{
	name:        'stat'
	description: 'Display file or file system status'
	help:        $embed_file('help.txt').to_string()
}

// Settings for Utility: stat
struct Settings {
mut:
	dereference bool
	file_system bool
	cache_mode  CacheMode
	format      string
	printf      string
	terse       bool
	input_files []string
}

struct MountInfo {
	fs_type     string
	mount_point string
}

struct StatxTimestamp {
	tv_sec  i64
	tv_nsec u32
}

struct Statx {
	stx_mask            u32 // Mask of bits indicating	filled              fields
	stx_blksize         u32 // Block size for filesystem I/O
	stx_attributes      u64 // Extra file attribute indicators
	stx_nlink           u32 // Number of hard links
	stx_uid             u32 // User ID of owner
	stx_gid             u32 // Group ID of owner
	stx_mode            u16 // File type and mode
	stx_ino             u64 // Inode number
	stx_size            u64 // Total size in bytes
	stx_blocks          u64 // Number of 512B blocks allocated
	stx_attributes_mask u64
	// Mask to show what's supported 									in stx_attributes
	// The following fields are file timestamps
	stx_atime StatxTimestamp // Last access
	stx_btime StatxTimestamp // Creation
	stx_ctime StatxTimestamp // Last status change
	stx_mtime StatxTimestamp // Last modification
	// If this file represents a device, then the next two 			fields contain the ID of the device
	stx_rdev_major u32 // Major ID
	stx_rdev_minor u32 // Minor ID
	// The next two fields contain the ID of the device 			containing the filesystem where the file resides
	stx_dev_major u32 // Major ID
	stx_dev_minor u32 // Minor ID

	stx_mnt_id u64 // Mount ID
	// Direct I/O alignment restrictions
	stx_dio_mem_align    u32
	stx_dio_offset_align u32
}

struct Statvfs {
	f_bsize   u64 // Filesystem block size
	f_frsize  u64 // Fragment size
	f_blocks  u64 // Size of fs in f_frsize units
	f_bfree   u64 // Number of free blocks
	f_bavail  u64 // Number of free blocks for unprivileged users
	f_files   u64 // Number of inodes
	f_ffree   u64 // Number of free inodes
	f_favail  u64 // Number of free inodes for unprivileged users
	f_fsid    u64 // Filesystem ID
	f_flag    u64 // Mount flags
	f_namemax u64 // Maximum filename length
}

enum CacheMode {
	_default
	always
	never
}

// Define all %_ format specifiers that we handle
// The 'V' at the end is a cheat for GNU compatibility (see process_token())
const tokens_statx = 'aAbBCdDfFgGhimnNosrRtTuUwWxXyYzZV'.bytes()
const tokens_statvfs = 'abcdfilnsStT'.bytes()

@[inline]
fn make_dev(major u32, minor u32) u32 {
	return major << 8 | minor
}

fn datetime_for_humans(ts StatxTimestamp) string {
	t := time.unix_nanosecond(ts.tv_sec, int(ts.tv_nsec)).utc_to_local()
	return '${t.format_ss_nano()} ${dtoffset_for_humans(t)}'
}

fn dtoffset_for_humans(ts time.Time) string {
	if ts.is_local {
		total_minutes := time.offset() / 60 // Integer division
		hours := total_minutes / 60
		minutes := total_minutes % 60
		sign := if hours < 0 { '-' } else { '+' }
		return '${sign}${hours:02}${minutes:02}'
	}
	// UTC
	return 'Z'
}

fn quote(s string) string {
	if s.contains("'") {
		if s.contains('"') {
			return '"' + s.replace("'", "\\'") + '"'
		}
		return '"' + s + '"'
	}
	return "'" + s + "'"
}

fn find_longest_match(needle string, haystack []string) string {
	mut max_match := ''
	for i := 0; i < haystack.len; i++ {
		if needle.starts_with(haystack[i]) {
			if max_match.len < haystack[i].len {
				max_match = haystack[i]
			}
		}
	}
	return max_match
}

fn process_token(token string, st Statx, path string, mtab []MountInfo) string {
	return match token {
		'a' {
			'${st.stx_mode & c_chmod_bits:04o}'
		}
		'A' {
			'${filemode_to_string(st.stx_mode)}'
		}
		'b' {
			'${st.stx_blocks}'
		}
		'B' {
			'${st.stx_blksize}'
		}
		'C' {
			app.quit(
				message:     'Sadly, SELinux is not supported yet.'
				return_code: common.err_not_implemented
			)
		}
		'd' {
			'${make_dev(st.stx_dev_major, st.stx_dev_minor)}'
		}
		'D' {
			'${make_dev(st.stx_dev_major, st.stx_dev_minor):x}'
		}
		'f' {
			'${st.stx_mode:4x}'
		}
		'F' {
			ft := get_filetype(st.stx_mode)
			if ft == .regular && st.stx_size == 0 {
				'regular empty file'
			} else {
				filetype_to_string(ft)
			}
		}
		'g' {
			'${st.stx_gid}'
		}
		'G' {
			name := pwd.get_name_for_gid(int(st.stx_gid)) or { 'Unknown group ${st.stx_gid}' }
			'${name}'
		}
		'h' {
			'${st.stx_nlink}'
		}
		'i' {
			'${st.stx_ino}'
		}
		'm' {
			// We want to find the longest match, otherwise /dev/pts/1 could
			// return /dev instead of /dev/pts as mountpoint, for example
			return find_longest_match(os.abs_path(path), mtab.map(it.mount_point))
		}
		'n' {
			path
		}
		'N' {
			ft := get_filetype(st.stx_mode)
			if ft == .symbolic_link {
				quote(path) + ' -> ' + quote(realpath(path, 1))
			} else {
				quote(path)
			}
		}
		'V' {
			// TODO: This is a cheat to cope with the default formatting that somehow
			// does not trigger quoting in the real GNU coreutils and I did see the
			// mechanism
			ft := get_filetype(st.stx_mode)
			if ft == .symbolic_link {
				path + ' -> ' + realpath(path, 1)
			} else {
				path
			}
		}
		'o' {
			'${st.stx_blksize}'
		}
		's' {
			'${st.stx_size}'
		}
		't' {
			'${st.stx_rdev_major:x}'
		}
		'T' {
			'${st.stx_rdev_minor:x}'
		}
		'u' {
			'${st.stx_uid}'
		}
		'U' {
			name := pwd.get_name_for_uid(int(st.stx_uid)) or { 'Unknown user ${st.stx_uid}' }
			'${name}'
		}
		'w' {
			'${datetime_for_humans(st.stx_btime)}'
		}
		'W' {
			'${st.stx_btime.tv_sec}'
		}
		'x' {
			'${datetime_for_humans(st.stx_atime)}'
		}
		'X' {
			'${st.stx_atime.tv_sec}'
		}
		'y' {
			'${datetime_for_humans(st.stx_mtime)}'
		}
		'Y' {
			'${st.stx_mtime.tv_sec}'
		}
		'z' {
			'${datetime_for_humans(st.stx_ctime)}'
		}
		'Z' {
			'${st.stx_ctime.tv_sec}'
		}
		else {
			'?'
		}
	}
}

fn process_token_fs(token string, st Statvfs, path string, mtab []MountInfo, fslist map[string]u32) string {
	return match token {
		'a' {
			'${st.f_bavail}'
		}
		'b' {
			'${st.f_blocks}'
		}
		'c' {
			'${st.f_files}'
		}
		'd' {
			'${st.f_ffree}'
		}
		'f' {
			'${st.f_bfree}'
		}
		'i' {
			'${st.f_fsid:x}'
		}
		'l' {
			'${st.f_namemax}'
		}
		'n' {
			path
		}
		's' {
			'${st.f_bsize}'
		}
		'S' {
			// TODO: verify
			'${st.f_bsize}'
		}
		't' {
			mount_point := find_longest_match(os.abs_path(path), mtab.map(it.mount_point))
			fs_type := mtab.filter(it.mount_point == mount_point).map(it.fs_type)[0]
			if fs_id := fslist[fs_type] {
				'${fs_id:x}'
			} else {
				'?'
			}
		}
		'T' {
			// We want to find the longest match, otherwise /dev/pts/1 could
			// return /dev instead of /dev/pts as mountpoint, for example
			mount_point := find_longest_match(os.abs_path(path), mtab.map(it.mount_point))
			'${mtab.filter(it.mount_point == mount_point).map(it.fs_type)[0]}'
		}
		else {
			'?'
		}
	}
}

fn scan_num(s &string) int {
	mut point_seen := false
	for i := 0; i < (*s).len; i++ {
		c := (*s)[i]
		if !((i == 0 && (c == `+` || c == `-`)) || (c.is_digit())) {
			return i
		}
		// Only one decimal point allowed
		if c == `.` && point_seen {
			return i
		}
	}
	return (*s).len
}

// TODO: When we upgrade to coreutil 9.4 compatibility, we will need two-byte tokens
// if (*s).len > 1 && (*s)[..2] in ['Hd', 'Hr', 'Ld', 'Lr'] {
// 	return 2
// }
fn scan_for_tokens(s &string, tokens []u8) int {
	if (*s).len > 0 {
		if (*s)[0] in tokens {
			return 1
		}
	}
	return 0
}

fn format_str(s string, format string) {
	unsafe { strconv.v_printf(format, voidptr(&s)) }
}

fn format_output(path string, st Statx, fmt string, mtab []MountInfo) {
	for i := 0; i < fmt.len; i++ {
		if fmt[i..i + 1] == '%' {
			if i + 1 < fmt.len && fmt[i + 1..i + 2] == '%' {
				print('%')
				i++
				continue
			}
			mut format := ''
			mut token := ''
			mut s := fmt[i + 1..]
			mut j := scan_num(&s)
			if j > 0 {
				format = fmt[i + 1..i + 1 + j]
				i += j
			}
			s = fmt[i + 1..]
			j = scan_for_tokens(&s, tokens_statx)
			if j > 0 {
				token = fmt[i + 1..i + 1 + j]
				i += j
			}
			if format != '' {
				format_str(process_token(token, st, path, mtab), '%${format}s')
			} else {
				print(process_token(token, st, path, mtab))
			}
		} else {
			print(fmt[i..i + 1])
		}
	}
}

fn format_output_fs(path string, st Statvfs, fmt string, mtab []MountInfo, fslist map[string]u32) {
	for i := 0; i < fmt.len; i++ {
		if fmt[i..i + 1] == '%' {
			if i + 1 < fmt.len && fmt[i + 1..i + 2] == '%' {
				print('%')
				i++
				continue
			}
			mut format := ''
			mut token := ''
			mut s := fmt[i + 1..]
			mut j := scan_num(&s)
			if j > 0 {
				format = fmt[i + 1..i + 1 + j]
				i += j
			}
			s = fmt[i + 1..]
			j = scan_for_tokens(&s, tokens_statvfs)
			if j > 0 {
				token = fmt[i + 1..i + 1 + j]
				i += j
			}
			if format != '' {
				format_str(process_token_fs(token, st, path, mtab, fslist), '%${format}s')
			} else {
				print(process_token_fs(token, st, path, mtab, fslist))
			}
		} else {
			print(fmt[i..i + 1])
		}
	}
}

fn stat(settings Settings) {
	mut mtab := []MountInfo{}
	mut fslist := map[string]u32{}
	// Only load mount table if we need the info from it
	if (settings.file_system && settings.format.contains('%T'))
		|| (!settings.file_system && settings.format.contains('%m')) {
		mtab = get_mount_list()
	}
	if settings.file_system && settings.format.contains('%t') {
		fslist = get_fs_list()
	}
	for fname in settings.input_files {
		if settings.file_system {
			if st := statvfs(fname) {
				format_output_fs(fname, st, settings.format, mtab, fslist)
			} else {
				app.eprintln_posix("cannot statx '${fname}'")
			}
		} else {
			// Individual files
			if st := statx(fname, settings.dereference, settings.cache_mode) {
				format_output(fname, st, settings.format, mtab)
			} else {
				app.eprintln_posix("cannot cannot read file system information for '${fname}'")
			}
		}
	}
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	st.dereference = fp.bool('dereference', `L`, false, 'follow links')
	st.file_system = fp.bool('file-system', `f`, false, 'display file system status instead of file status')
	cached := fp.string('cached', 0, 'default', 'specify how to use cached attributes; useful on remote file systems. See MODE below')
	format := fp.string_multi('format', `c`, 'use the specified FORMAT instead of the default; output a newline after each use of FORMAT')
	printf := fp.string_multi('printf', 0, 'like --format, but interpret backslash escapes, and do not output a mandatory trailing newline if you want a newline, include \n in FORMAT')
	st.terse = fp.bool('terse', `t`, false, 'print the information in terse form')
	st.input_files = fp.remaining_parameters()
	match cached {
		'default' {
			st.cache_mode = ._default
		}
		'always' {
			st.cache_mode = .always
		}
		'never' {
			st.cache_mode = .never
		}
		else {
			app.quit(
				message:          'invalid argument ‘${cached}’ for ‘--cached’\nValid arguments are:\n  - ‘default’\n  - ‘never’\n  - ‘always’'
				show_help_advice: true
			)
		}
	}
	if st.input_files.len == 0 {
		app.quit(message: 'missing operand')
	}

	// Format overrides --terse
	// The behavior of GNU utils is not reproduced with flag_parser
	// GNU utils go in order:
	// stat --printf "%a" --format "%n" --printf "%s" => last --printf takes predecence
	// stat --printf "%a" --format "%n" => last --format takes predecence
	// stat --printf "%a" --format "%n" --terse => last --format takes predecence, terse overriden
	if format.len > 0 && printf.len > 0 {
		app.quit(message: "--format and --printf can't both be specified")
	}
	if format.len == 0 && printf.len == 0 {
		if st.terse {
			if st.file_system {
				st.format = '%n %i %l %t %s %S %b %f %a %c %d\n'
			} else {
				st.format = '%n %s %b %f %u %g %D %i %h %t %T %X %Y %Z %W %o\n'
			}
		} else {
			if st.file_system {
				st.format = '  File: "%n"\n    ID: %-8i Namelen: %-7l Type: %T\nBlock size: %-10s Fundamental block size: %S\nBlocks: Total: %-10b Free: %-10f Available: %a\nInodes: Total: %-10c Free: %d\n'
			} else {
				st.format = '  File: %V\n  Size: %-10s\tBlocks: %-10b IO Block: %-6o %F\nDevice: %Dh/%dd\tInode: %-10i  Links: %h\nAccess: (%04a/%10A)  Uid: (%5u/%8U)   Gid: (%5g/%8G)\nAccess: %x\nModify: %y\nChange: %z\n Birth: %w\n'
			}
		}
	} else {
		if format.len > 0 {
			// Latest one takes precedence, just like in GNU
			// --format appends \n automatically
			st.format = format[format.len - 1] + '\n'
		} else if printf.len > 0 {
			st.format = raw_to_printf_string(printf[printf.len - 1])
		} else {
			// [UNREACHBLE]
			app.quit(
				message:     'error in command line handling'
				return_code: common.err_programming_error
			)
		}
	}
	return st
}

fn main() {
	stat(args())
}

fn get_mount_list() []MountInfo {
	$if !linux {
		app.quit(
			message:     'reading mounts is not supported on this platform'
			return_code: common.err_platform_not_supported
		)
	}
	mut file := os.open('/etc/mtab') or { app.quit(message: 'Unable to read /etc/mtab') }
	defer {
		file.close()
	}
	mut br := io.new_buffered_reader(io.BufferedReaderConfig{ reader: file })
	defer {
		br.free()
	}
	mut mounts := []MountInfo{}
	for {
		line := br.read_line(delim: `\n`) or { break }
		mi := line.split(' ')
		mounts << MountInfo{
			fs_type:     mi[2]
			mount_point: mi[1]
		}
	}
	return mounts
}

fn get_fs_list() map[string]u32 {
	embedded_file := $embed_file('fstypes.txt')
	s := embedded_file.to_string()
	assert s[s.len - 1] == `\n`, 'fstypes.txt must be newline-terminated.'
	mut fslist := map[string]u32{}
	for i := 0; i < s.len; {
		assert s[i..i + 2] == r'0x'
		assert s[i + 10] == ` `
		type_id := s[i + 2..i + 10].trim_right(' ')
		i += 11
		j := s.index_after('\n', i)
		fs_name := s[i..j]
		i = j + 1
		fslist[fs_name] = u32(strconv.parse_uint(type_id, 16, 32) or {
			app.quit(
				message:     'Unable to parse fstype `${fs_name}`: [${type_id}]'
				return_code: common.err_programming_error
			)
		})
	}
	return fslist
}
