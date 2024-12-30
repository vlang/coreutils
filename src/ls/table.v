const table_border = `─`
const table_border_pad_right = ' │' // border for between cells
const table_border_pad_left = '│ '
const table_border_divider = `│`
const table_border_top_start = `┌`
const table_border_top_end = `┐`
const table_border_mid_start = `├`
const table_border_mid_end = `┤`
const table_border_bot_start = `└`
const table_border_bot_end = `┘`
const table_border_t = `┬`
const table_border_u_t = `┴`
const table_border_cross = `┼`
const table_border_size = 2

fn print_header_border(options Options, len int, cols []int) {
	if options.table_format {
		border := if options.header {
			border_row_middle(len, cols)
		} else {
			border_row_top(len, cols)
		}
		print(border)
	} else {
		if options.header {
			println(format_header_text_border(len, options))
		}
	}
}

fn print_bottom_border(options Options, len int, cols []int) {
	if options.table_format {
		print(border_row_bottom(len, cols))
	}
}

fn border_row_top(len int, cols []int) string {
	return format_table_border(len, cols, table_border_t, table_border_top_start, table_border_top_end)
}

fn border_row_bottom(len int, cols []int) string {
	return format_table_border(len, cols, table_border_u_t, table_border_bot_start, table_border_bot_end)
}

fn border_row_middle_end(len int, cols []int) string {
	return format_table_border(len, cols, table_border_u_t, table_border_mid_start, table_border_mid_end)
}

fn border_row_middle(len int, cols []int) string {
	return format_table_border(len, cols, table_border_cross, table_border_mid_start,
		table_border_mid_end)
}

fn format_table_border(len int, cols []int, divider rune, start rune, end rune) string {
	mut border := table_border.repeat(len).runes()
	border[0] = start
	border[border.len - 1] = end
	for col in cols {
		border[col - 1] = divider
	}
	return '${border.string()}\n'
}

fn format_header_text_border(len int, options Options) string {
	dim := if options.no_dim { no_style } else { dim_style }
	divider := '┈'.repeat(len)
	return format_cell(divider, 0, .left, dim, options)
}
