import arrays
import os
import term
import v.mathutil

const cell_max = 12 // limit on wide displays
const cell_spacing = 3 // space between cells

enum Align {
	left
	right
}

fn print_files(entries_arg []Entry, options Options) {
	entries := match true {
		options.all && !options.almost_all {
			dot := make_entry('.', '.', options)
			dot_dot := make_entry('..', '.', options)
			arrays.concat([dot, dot_dot], ...entries_arg)
		}
		else {
			entries_arg
		}
	}

	w, _ := term.get_terminal_size()
	options_width_ok := options.width_in_cols > 0 && options.width_in_cols < 1000
	width := if options_width_ok { options.width_in_cols } else { w }

	match true {
		// vfmt off
		options.long_format 				  { format_long_listing(entries, options) }
		options.list_by_lines && !options.list_by_columns { format_by_lines(entries, width, options) }
		options.with_commas 				  { format_with_commas(entries, options) }
		options.one_per_line 				  { format_one_per_line(entries, options) }
		else 						  { format_by_cells(entries, width, options) }
		// vfmt on
	}
}

fn format_by_cells(entries []Entry, width int, options Options) {
	len := entries.max_name_len(options) + cell_spacing
	cols := mathutil.min(width / len, cell_max)
	max_cols := mathutil.max(cols, 1)
	partial_row := entries.len % max_cols != 0
	rows := entries.len / max_cols + if partial_row { 1 } else { 0 }
	max_rows := mathutil.max(1, rows)

	for r := 0; r < max_rows; r += 1 {
		for c := 0; c < max_cols; c += 1 {
			idx := r + c * max_rows
			if idx < entries.len {
				entry := entries[idx]
				name := format_entry_name(entry, options)
				cell := format_cell(name, len, .left, get_style_for_entry(entry, options),
					options)
				print(cell)
			}
		}
		print_newline()
	}
}

fn format_by_lines(entries []Entry, width int, options Options) {
	len := entries.max_name_len(options) + cell_spacing
	cols := mathutil.min(width / len, cell_max)
	max_cols := mathutil.max(cols, 1)

	for i, entry in entries {
		if i % max_cols == 0 && i != 0 {
			print_newline()
		}
		name := format_entry_name(entry, options)
		cell := format_cell(name, len, .left, get_style_for_entry(entry, options), options)
		print(cell)
	}
	print_newline()
}

fn format_one_per_line(entries []Entry, options Options) {
	for entry in entries {
		println(format_cell(entry.name, 0, .left, get_style_for_entry(entry, options),
			options))
	}
}

fn format_with_commas(entries []Entry, options Options) {
	last := entries.len - 1
	for i, entry in entries {
		content := if i < last { '${entry.name}, ' } else { entry.name }
		print(format_cell(content, 0, .left, no_style, options))
	}
	print_newline()
}

fn format_cell(s string, width int, align Align, style Style, options Options) string {
	return match options.table_format {
		true { format_table_cell(s, width, align, style, options) }
		else { format_cell_content(s, width, align, style, options) }
	}
}

fn format_cell_content(s string, width int, align Align, style Style, options Options) string {
	mut cell := ''
	no_ansi_s := term.strip_ansi(s)
	pad := width - no_ansi_s.runes().len

	if align == .right && pad > 0 {
		cell += space.repeat(pad)
	}

	cell += if options.colorize == when_always {
		style_string(s, style, options)
	} else {
		no_ansi_s
	}

	if align == .left && pad > 0 {
		cell += space.repeat(pad)
	}

	return cell
}

fn format_table_cell(s string, width int, align Align, style Style, options Options) string {
	cell := format_cell_content(s, width, align, style, options)
	return '${cell}${table_border_pad_right}'
}

// surrounds a cell with table borders
fn print_dir_name(name string, options Options) {
	if name.len > 0 {
		print_newline()
		nm := if options.colorize == when_always {
			style_string(name, options.style_di, options)
		} else {
			name
		}
		println('${nm}:')
	}
}

fn (entries []Entry) max_name_len(options Options) int {
	lengths := entries.map(real_length(format_entry_name(it, options)))
	return arrays.max(lengths) or { 0 }
}

fn get_style_for_entry(entry Entry, options Options) Style {
	return match true {
		// vfmt off
		entry.link 	{ options.style_ln }
		entry.dir 	{ options.style_di }
		entry.exe 	{ options.style_ex }
		entry.fifo 	{ options.style_pi }
		entry.block 	{ options.style_bd }
		entry.character { options.style_cd }
		entry.socket 	{ options.style_so }
		entry.file 	{ options.style_fi }
		else 		{ no_style }
		// vfmt on
	}
}

fn get_style_for_link(entry Entry, options Options) Style {
	if entry.link_stat.size == 0 {
		return unknown_style
	}

	filetype := entry.link_stat.get_filetype()
	is_dir := filetype == os.FileType.directory
	is_fifo := filetype == .fifo
	is_block := filetype == .block_device
	is_socket := filetype == .socket
	is_character_device := filetype == .character_device
	is_unknown := filetype == .unknown
	is_exe := is_executable(entry.link_stat)
	is_file := !is_dir && !is_fifo && !is_block && !is_socket && !is_character_device && !is_unknown
		&& !is_exe

	return match true {
		// vfmt off
		is_dir 		    { options.style_di }
		is_exe 		    { options.style_ex }
		is_fifo 	    { options.style_pi }
		is_block 	    { options.style_bd }
		is_character_device { options.style_cd }
		is_socket 	    { options.style_so }
		is_unknown 	    { unknown_style }
		is_file 	    { options.style_fi }
		else 		    { no_style }
		// vfmt on
	}
}

fn format_entry_name(entry Entry, options Options) string {
	name := if options.relative_path {
		os.join_path(entry.dir_name, entry.name)
	} else {
		entry.name
	}

	icon := get_icon_for_entry(entry, options)

	return match true {
		entry.link {
			link_style := get_style_for_link(entry, options)
			missing := if link_style == unknown_style { ' (not found)' } else { '' }
			link := style_string(entry.link_origin, link_style, options)
			'${icon}${name} -> ${link}${missing}'
		}
		options.quote {
			'"${icon}${name}"'
		}
		else {
			'${icon}${name}'
		}
	}
}

fn real_length(s string) int {
	return term.strip_ansi(s).runes().len
}

@[inline]
fn print_space() {
	print_character(` `)
}

@[inline]
fn print_newline() {
	print_character(`\n`)
}
