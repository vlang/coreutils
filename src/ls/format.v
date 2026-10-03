import arrays
import os
import term
import math

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
	// GNU falls back to 80 columns when there is no terminal, so ls -C | cat
	// still makes a grid. Without this the column layouts collapse to one
	// entry per line as soon as the output is redirected.
	width := if options_width_ok {
		options.width_in_cols
	} else if w > 0 {
		w
	} else {
		80
	}

	match true {
		// vfmt off
		options.long_format 				  { format_long_listing(entries, options) }
		options.list_by_lines 				  { format_by_lines(entries, width, options) }
		options.with_commas 				  { format_with_commas(entries, width, options) }
		options.one_per_line 				  { format_one_per_line(entries, options) }
		options.list_by_columns 				  { format_by_cells(entries, width, options) }
		// GNU fills the width with columns only when the output is a terminal.
		// Piped or redirected it lists one entry per line, so `ls | cat` and
		// `ls` in a terminal do not agree unless -C was given.
		os.is_atty(1) == 0 				  { format_one_per_line(entries, options) }
		else 						  { format_by_cells(entries, width, options) }
		// vfmt on
	}
}

fn format_by_cells(entries []Entry, width int, options Options) {
	len := entries.max_name_len(options) + cell_spacing
	cols := math.min(width / len, cell_max)
	max_cols := math.max(cols, 1)
	partial_row := entries.len % max_cols != 0
	rows := entries.len / max_cols + if partial_row { 1 } else { 0 }
	max_rows := math.max(1, rows)

	for r := 0; r < max_rows; r += 1 {
		for c := 0; c < max_cols; c += 1 {
			idx := r + c * max_rows
			if idx < entries.len {
				entry := entries[idx]
				name := format_entry_name(entry, options)
				// The last column of a row is not padded: GNU never ends a
				// line with the spaces that would align it to the next one.
				width_here := if c == max_cols - 1 { 0 } else { len }
				cell := format_cell(name, width_here, .left, get_style_for_entry(entry,
					options), options)
				print(cell)
			}
		}
		print_newline()
	}
}

fn format_by_lines(entries []Entry, width int, options Options) {
	len := entries.max_name_len(options) + cell_spacing
	cols := math.min(width / len, cell_max)
	max_cols := math.max(cols, 1)

	for i, entry in entries {
		if i % max_cols == 0 && i != 0 {
			print_newline()
		}
		name := format_entry_name(entry, options)
		width_here := if i % max_cols == max_cols - 1 { 0 } else { len }
		cell := format_cell(name, width_here, .left, get_style_for_entry(entry, options), options)
		print(cell)
	}
	print_newline()
}

fn format_one_per_line(entries []Entry, options Options) {
	for entry in entries {
		// -i on its own is `%i  %n`: the inode and then the name, no other
		// column. GNU puts one space between them.
		prefix := if options.inode { '${entry.stat.inode} ' } else { '' }
		println('${prefix}${format_cell(format_entry_name(entry, options), 0, .left, get_style_for_entry(entry, options), options)}')
	}
}

// -m fills the width with a comma separated list. The comma is written after
// every entry but the last and the space before the next one is only written
// when there is room for it, so a wrapped line ends in `large.bin,` and not in
// `large.bin, ` the way padding each cell would leave it.
fn format_with_commas(entries []Entry, width int, options Options) {
	last := entries.len - 1
	mut line := 0
	for i, entry in entries {
		name := format_entry_name(entry, options)
		if line > 0 {
			if line + 1 + real_length(name) > width {
				print_newline()
				line = 0
			} else {
				print(' ')
				line += 1
			}
		}
		print(format_cell(name, 0, .left, no_style, options))
		if i < last {
			print(',')
		}
		line += real_length(name)
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
fn print_dir_name(name string, options Options, printed_any &bool) {
	if name.len > 0 {
		// A blank line separates sections, but there is none before the first.
		if *printed_any {
			print_newline()
		}
		unsafe {
			*printed_any = true
		}
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
		entry_path(entry.dir_name, entry.name)
	} else {
		entry.name
	}

	icon := get_icon_for_entry(entry, options)

	// The quoting style defaults per destination: a terminal gets shell rules,
	// a pipe gets none. -Q is GNU's older spelling of --quoting-style=c, not of
	// shell quoting: measured, `ls -Q` prints "new\nline" with a C escape.
	style := if options.quote && options.quoting_style == '' {
		'c'
	} else if options.quoting_style != '' {
		options.quoting_style
	} else if os.is_atty(1) != 0 {
		'shell-escape'
	} else {
		'literal'
	}

	return match true {
		entry.link && options.long_format {
			link_style := get_style_for_link(entry, options)
			link := style_string(quote_name(entry.link_origin, style), link_style, options)
			'${icon}${quote_name(name, style)} -> ${link}'
		}
		else {
			'${icon}${quote_name(name, style)}'
		}
	}
}

// GNU's --quoting-style, measured on the reference rather than recalled.
// `literal` never quotes. `shell` quotes only a name that needs it, `shell-
// always` quotes every one, and both use shell rules: single quotes normally,
// double quotes when the name contains a single quote, and the quoted run
// closes and reopens around an embedded newline so the name stays one argument.
// `c` is always double quoted with C escapes.
fn quote_name(name string, style string) string {
	return match style {
		'c' { c_quote(name) }
		'shell' { shell_quote(name, false) }
		'shell-always' { shell_quote(name, true) }
		'shell-escape' { shell_escape_quote(name, false) }
		'shell-escape-always' { shell_escape_quote(name, true) }
		else { name }
	}
}

// shell-escape differs from shell in how it treats a byte that is not printable
// ASCII: instead of leaving a newline or a tab inside the single quotes, it
// closes the run and writes $'\n' or a three digit octal escape, so a name with
// a tab in it comes out as 'tab'$'\t''name'. Bytes at or above 0x80 are escaped
// the same way, which is how GNU writes ü as ''$'\303\274''.
fn shell_escape_quote(name string, always bool) string {
	if !always && !needs_quoting(name) {
		return name
	}
	mut out := ''
	mut run := ''
	mut i := 0
	for i < name.len {
		b := name[i]
		if b >= 0x20 && b < 0x7f {
			run += name[i..i + 1]
			i++
			continue
		}
		out += quote_run(run)
		run = ''
		out += match b {
			`\n` { "$'\\n'" }
			`\t` { "$'\\t'" }
			`\r` { "$'\\r'" }
			else { "$'\\${b:03o}'" }
		}
		i++
	}
	return out + quote_run(run)
}

// A name needs no quoting when it is made only of characters a shell treats
// literally, which is the same set GNU uses to decide this. A newline needs
// quoting and a shell is happy to have it inside single quotes, which is why a
// two line name comes out as 'new<newline>line' with the quotes still open.
fn needs_quoting(name string) bool {
	if name.len == 0 {
		return true
	}
	for ch in name {
		if !(ch >= `a` && ch <= `z`) && !(ch >= `A` && ch <= `Z`) && !(ch >= `0` && ch <= `9`)
			&& ch != `@` && ch != `%` && ch != `_` && ch != `+` && ch != `=` && ch != `:` && ch != `,`
			&& ch != `.` && ch != `/` && ch != `-` {
			return true
		}
	}
	return false
}

fn shell_quote(name string, always bool) string {
	if !always && !needs_quoting(name) {
		return name
	}
	return quote_run(name)
}

// quote_run wraps one run of characters in the quotes a shell would use.
fn quote_run(run string) string {
	if run.len == 0 {
		return ''
	}
	// A single quote cannot appear inside single quotes, so such a name is
	// double quoted instead, with the double quote, backslash and dollar
	// escaped.
	if run.contains("'") {
		mut out := '"'
		for i in 0 .. run.len {
			if run[i] == `"` || run[i] == `\\` || run[i] == `$` {
				out += '\\'
			}
			out += run[i..i + 1]
		}
		return out + '"'
	}
	return "'${run}'"
}

fn c_quote(name string) string {
	mut out := '"'
	for i in 0 .. name.len {
		out += match name[i] {
			`"` { '\\"' }
			`\\` { '\\\\' }
			`\n` { '\\n' }
			`\t` { '\\t' }
			`\r` { '\\r' }
			else { name[i..i + 1] }
		}
	}
	return out + '"'
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
