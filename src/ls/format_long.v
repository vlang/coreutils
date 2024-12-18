import arrays
import os
import term
import time
import v.mathutil { max }

const inode_title = 'inode'
const permissions_title = 'Permissions'
const mask_title = 'Mask'
const links_title = 'Links'
const owner_title = 'Owner'
const group_title = 'Group'
const size_title = 'Size'
const date_modified_title = 'Modified'
const date_accessed_title = 'Accessed'
const date_status_title = 'Status Change'
const name_title = 'Name'
const unknown = '?'
const block_size = 5
const space = ' '
const date_format = 'MMM DD YYYY HH:mm:ss'
const date_iso_format = 'YYYY-MM-DD HH:mm:ss'
const date_compact_format = "DD MMM'YY HH:mm"
const date_compact_format_with_day = "ddd DD MMM'YY HH:mm"

struct Longest {
	inode      int
	nlink      int
	owner_name int
	group_name int
	size       int
	checksum   int
	file       int
}

enum StatTime {
	accessed
	changed
	modified
}

fn format_long_listing(entries []Entry, options Options) {
	longest := longest_entries(entries, options)
	header, cols := format_header(options, longest)
	header_len := real_length(header)
	term_cols, _ := term.get_terminal_size()

	print_header(header, options, header_len, cols)
	print_header_border(options, header_len, cols)

	dim := if options.no_dim { no_style } else { dim_style }

	for idx, entry in entries {
		// emit blank row every 5th row
		if options.blocked_output {
			if idx % block_size == 0 && idx != 0 {
				match options.table_format {
					true { print(border_row_middle(header_len, cols)) }
					else { print_newline() }
				}
			}
		}

		// left table border
		if options.table_format {
			print(table_border_pad_left)
		}

		// inode
		if options.inode {
			content := if entry.invalid { unknown } else { entry.stat.inode.str() }
			print(format_cell(content, longest.inode, Align.right, no_style, options))
			print_space()
		}

		// checksum
		if options.checksum != '' {
			checksum := format_cell(entry.checksum, longest.checksum, .left, dim, options)
			print(checksum)
			print_space()
		}

		// permissions
		if !options.no_permissions {
			flag := file_flag(entry, options)
			print(format_cell(flag, 1, .left, no_style, options))
			print_space()

			content := permissions(entry, options)
			print(format_cell(content, permissions_title.len, .right, no_style, options))
			print_space()
		}

		// octal permissions
		if options.octal_permissions {
			content := format_octal_permissions(entry, options)
			print(format_cell(content, 4, .left, dim, options))
			print_space()
		}

		// hard links
		if !options.no_hard_links {
			content := if entry.invalid { unknown } else { '${entry.stat.nlink}' }
			print(format_cell(content, longest.nlink, .right, dim, options))
			print_space()
		}

		// owner name
		if !options.no_owner_name {
			content := if entry.invalid { unknown } else { get_owner_name(entry.stat.uid) }
			print(format_cell(content, longest.owner_name, .right, dim, options))
			print_space()
		}

		// group name
		if !options.no_group_name {
			content := if entry.invalid { unknown } else { get_group_name(entry.stat.gid) }
			print(format_cell(content, longest.group_name, .right, dim, options))
			print_space()
		}

		// size
		if !options.no_size {
			content := match true {
				// vfmt off
				entry.invalid 				{ unknown }
				entry.dir || entry.socket || entry.fifo { '-' }
				options.size_ki && !options.size_kb 	{ entry.size_ki }
				options.size_kb 			{ entry.size_kb }
				else 					{ entry.size.str() }
				// vfmt on
			}
			size_style := match entry.link_stat.size > 0 {
				true { get_style_for_link(entry, options) }
				else { get_style_for_entry(entry, options) }
			}
			size := format_cell(content, longest.size, .right, size_style, options)
			print(size)
			print_space()
		}

		// date/time(modified)
		if !options.no_date {
			print(format_time(entry, .modified, options))
			print_space()
		}

		// date/time (accessed)
		if options.accessed_date {
			print(format_time(entry, .accessed, options))
			print_space()
		}

		// date/time (status change)
		if options.changed_date {
			print(format_time(entry, .changed, options))
			print_space()
		}

		// file name
		file_name := format_entry_name(entry, options)
		file_style := get_style_for_entry(entry, options)
		match options.table_format {
			true { print(format_cell(file_name, longest.file, .left, file_style, options)) }
			else { print(format_cell(file_name, 0, .left, file_style, options)) }
		}

		// line too long? Print a '≈' in the last column
		if options.no_wrap {
			mut coord := term.get_cursor_position() or { term.Coord{} }
			if coord.x >= term_cols {
				coord.x = term_cols
				term.set_cursor_position(coord)
				print('≈')
			}
		}

		print_newline()
	}

	// bottom border
	print_bottom_border(options, header_len, cols)

	// stats
	if !options.no_count {
		statistics(entries, header_len, options)
	}
}

fn longest_entries(entries []Entry, options Options) Longest {
	return Longest{
		// vfmt off
		inode: 	    longest_inode_len(entries, inode_title, options)
		nlink: 	    longest_nlink_len(entries, links_title, options)
		owner_name: longest_owner_name_len(entries, owner_title, options)
		group_name: longest_group_name_len(entries, group_title, options)
		size: 	    longest_size_len(entries, size_title, options)
		checksum:   longest_checksum_len(entries, options.checksum, options)
		file: 	    longest_file_name_len(entries, name_title, options)
		// vfmt on
	}
}

fn print_header(header string, options Options, len int, cols []int) {
	if options.header {
		if options.table_format {
			print(border_row_top(len, cols))
		}
		println(header)
	}
}

fn format_header(options Options, longest Longest) (string, []int) {
	mut buffer := ''
	mut cols := []int{}
	dim := if options.no_dim || options.table_format { no_style } else { dim_style }
	table_pad := if options.table_format { table_border_pad_left } else { '' }

	if options.table_format {
		buffer += table_border_pad_left
	}
	if options.inode {
		title := if options.header { inode_title } else { '' }
		buffer += left_pad(title, longest.inode) + table_pad
		cols << real_length(buffer) - 1
	}
	if options.checksum != '' {
		title := if options.header { options.checksum.capitalize() } else { '' }
		width := longest.checksum
		buffer += right_pad(title, width) + table_pad
		cols << real_length(buffer) - 1
	}
	if !options.no_permissions {
		buffer += 'T ${table_pad}'
		cols << real_length(buffer) - 1
		buffer += left_pad(permissions_title, permissions_title.len) + table_pad
		cols << real_length(buffer) - 1
	}
	if options.octal_permissions {
		buffer += left_pad(mask_title, mask_title.len) + table_pad
		cols << real_length(buffer) - 1
	}
	if !options.no_hard_links {
		title := if options.header { links_title } else { '' }
		buffer += left_pad(title, longest.nlink) + table_pad
		cols << real_length(buffer) - 1
	}
	if !options.no_owner_name {
		title := if options.header { owner_title } else { '' }
		buffer += left_pad(title, longest.owner_name) + table_pad
		cols << real_length(buffer) - 1
	}
	if !options.no_group_name {
		title := if options.header { group_title } else { '' }
		buffer += left_pad(title, longest.group_name) + table_pad
		cols << real_length(buffer) - 1
	}
	if !options.no_size {
		title := if options.header { size_title } else { '' }
		buffer += left_pad(title, longest.size) + table_pad
		cols << real_length(buffer) - 1
	}
	if !options.no_date {
		title := if options.header { date_modified_title } else { '' }
		width := time_format(options).len
		buffer += right_pad(title, width) + table_pad
		cols << real_length(buffer) - 1
	}
	if options.accessed_date {
		title := if options.header { date_accessed_title } else { '' }
		width := time_format(options).len
		buffer += right_pad(title, width) + table_pad
		cols << real_length(buffer) - 1
	}
	if options.changed_date {
		title := if options.header { date_status_title } else { '' }
		width := time_format(options).len
		buffer += right_pad(title, width) + table_pad
		cols << real_length(buffer) - 1
	}

	buffer += right_pad_end(if options.header { name_title } else { '' }, longest.file) // drop last space
	header := format_cell(buffer, 0, .left, dim, options)
	return header, cols
}

fn time_format(options Options) string {
	return match true {
		// vfmt off
		options.time_iso     		{ date_iso_format }
		options.time_compact 		{ date_compact_format }
		options.time_compact_with_day 	{ date_compact_format_with_day }
		else 		     		{ date_format }
		// vfmt on
	}
}

fn left_pad(s string, width int) string {
	pad := width - s.len
	return if pad > 0 { space.repeat(pad) + s + space } else { s + space }
}

fn right_pad(s string, width int) string {
	pad := width - s.len
	return if pad > 0 { s + space.repeat(pad) + space } else { s + space }
}

fn right_pad_end(s string, width int) string {
	pad := width - s.len
	return if pad > 0 { s + space.repeat(pad) } else { s }
}

fn statistics(entries []Entry, len int, options Options) {
	file_count := entries.filter(it.file).len
	total := arrays.sum(entries.map(if it.file || it.exe { it.stat.size } else { 0 })) or { 0 }
	dir_count := entries.filter(it.dir).len
	link_count := entries.filter(it.link).len
	mut stats := ''

	dim := if options.no_dim { no_style } else { dim_style }
	file_count_styled := style_string(file_count.str(), options.style_fi, options)

	file := if file_count == 1 { 'file' } else { 'files' }
	files := style_string(file, dim, options)
	dir_count_styled := style_string(dir_count.str(), options.style_di, options)

	dir := if dir_count == 1 { 'directory' } else { 'directories' }
	dirs := style_string(dir, dim, options)

	size := match true {
		options.size_ki { readable_size(total, true) }
		options.size_kb { readable_size(total, false) }
		else { total.str() }
	}

	totals := style_string(size, options.style_fi, options)
	stats = '${dir_count_styled} ${dirs} | ${file_count_styled} ${files} [${totals}]'

	if link_count > 0 {
		link_count_styled := style_string(link_count.str(), options.style_ln, options)
		links := style_string('links', dim, options)
		stats += ' | ${link_count_styled} ${links}'
	}
	println(stats)
}

fn file_flag(entry Entry, options Options) string {
	return match true {
		// vfmt off
		entry.invalid 	{ unknown }
		entry.link 	{ style_string('l', options.style_ln, options) }
		entry.dir 	{ style_string('d', options.style_di, options) }
		entry.exe 	{ style_string('x', options.style_ex, options) }
		entry.fifo 	{ style_string('p', options.style_pi, options) }
		entry.block 	{ style_string('b', options.style_bd, options) }
		entry.character { style_string('c', options.style_cd, options) }
		entry.socket 	{ style_string('s', options.style_so, options) }
		entry.file	{ style_string('f', options.style_fi, options) }
		else 		{ ' ' }
		// vfmt on
	}
}

fn format_octal_permissions(entry Entry, options Options) string {
	mode := entry.stat.get_mode()
	return '0${mode.owner.bitmask()}${mode.group.bitmask()}${mode.others.bitmask()}'
}

fn permissions(entry Entry, options Options) string {
	mode := entry.stat.get_mode()
	owner := file_permission(mode.owner, options)
	group := file_permission(mode.group, options)
	other := file_permission(mode.others, options)
	return '${owner} ${group} ${other}'
}

fn file_permission(file_permission os.FilePermission, options Options) string {
	dim := if options.no_dim { no_style } else { dim_style }
	dash := style_string('-', dim, options)
	r := if file_permission.read { style_string('r', options.style_ln, options) } else { dash }
	w := if file_permission.write { style_string('w', options.style_fi, options) } else { dash }
	x := if file_permission.execute { style_string('x', options.style_ex, options) } else { dash }
	return '${r}${w}${x}'
}

fn format_time(entry Entry, stat_time StatTime, options Options) string {
	entry_time := match stat_time {
		.accessed { entry.stat.atime }
		.changed { entry.stat.ctime }
		.modified { entry.stat.mtime }
	}

	mut date := time.unix(entry_time)
		.local()
		.custom_format(time_format(options))

	if date.starts_with('0') {
		date = ' ' + date[1..]
	}

	dim := if options.no_dim { no_style } else { dim_style }
	content := if entry.invalid { '?' + space.repeat(date.len - 1) } else { date }
	return format_cell(content, date.len, .left, dim, options)
}

fn longest_nlink_len(entries []Entry, title string, options Options) int {
	lengths := entries.map(it.stat.nlink.str().len)
	max := arrays.max(lengths) or { 0 }
	return if options.no_hard_links || !options.header { max } else { max(max, title.len) }
}

fn longest_owner_name_len(entries []Entry, title string, options Options) int {
	lengths := entries.map(get_owner_name(it.stat.uid).len)
	max := arrays.max(lengths) or { 0 }
	return if options.no_owner_name || !options.header { max } else { max(max, title.len) }
}

fn longest_group_name_len(entries []Entry, title string, options Options) int {
	lengths := entries.map(get_group_name(it.stat.gid).len)
	max := arrays.max(lengths) or { 0 }
	return if options.no_group_name || !options.header { max } else { max(max, title.len) }
}

fn longest_size_len(entries []Entry, title string, options Options) int {
	lengths := entries.map(match true {
		it.dir { 1 }
		options.size_ki && !options.size_kb { it.size_ki.len }
		options.size_kb { it.size_kb.len }
		else { it.size.str().len }
	})
	max := arrays.max(lengths) or { 0 }
	return if options.no_size || !options.header { max } else { max(max, title.len) }
}

fn longest_inode_len(entries []Entry, title string, options Options) int {
	lengths := entries.map(it.stat.inode.str().len)
	max := arrays.max(lengths) or { 0 }
	return if !options.inode || !options.header { max } else { max(max, title.len) }
}

fn longest_file_name_len(entries []Entry, title string, options Options) int {
	lengths := entries.map(real_length(format_entry_name(it, options)))
	max := arrays.max(lengths) or { 0 }
	return if !options.header { max } else { max(max, title.len) }
}

fn longest_checksum_len(entries []Entry, title string, options Options) int {
	lengths := entries.map(it.checksum.len)
	max := arrays.max(lengths) or { 0 }
	return if !options.header { max } else { max(max, title.len) }
}
