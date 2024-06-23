import os

struct App {
	options Options
mut:
	// If true, convert blanks even after nonblank characters have been read on the line.
	convert_entire_line bool
	// If nonzero, the size of all tab stops.  If zero, use 'tab_list' instead.
	tab_size int
	// If nonzero, the size of all tab stops after the last specified.
	extend_size int
	// If nonzero, an increment for additional tab stops after the last specified.
	increment_size int
	// The maximum distance between tab stops.
	max_column_width int
	// Array of the explicit column numbers of the tab stops;
	// after 'tab_list' is exhausted, each additional tab is replaced
	// by a space.  The first column is column 0.
	tab_list []int
	// The number of allocated entries in 'tab_list'.
	n_tabs_allocated int
	// The index of the first invalid element of 'tab_list',
	// where the next element can be added.
	first_free_tab int
}

fn main() {
	mut app := App{
		options: get_options()
	}

	app.convert_entire_line = app.options.all

	if app.options.tabs.len > 0 {
		app.convert_entire_line = true
		parse_tab_stops(app.options.tabs.bytes(), mut app)
	}
	if app.options.first_only {
		app.convert_entire_line = false
	}

	finalize_tab_stops(mut app)
	unexpand(mut app)
}

fn unexpand(mut app App) {
	for file in app.options.files {
		unexpand_file(file, mut app)
	}
}

fn unexpand_file(file string, mut app App) {
	// The array of pending blanks.  In non-POSIX locales, blanks can
	// include characters other than spaces, so the blanks must be
	// stored, not merely counted.
	// char *pending_blank;
	mut pending_blank := []rune{len: app.max_column_width}

	lines := os.read_lines(file) or { exit_error(err.msg()) }
	for line in lines {
		// If true, perform translations.
		mut convert := true
		// The following variables have valid values only when CONVERT is true:
		// g of next input character.
		mut column := 0
		// Column the next input tab stop is on.
		mut next_tab_column := 0
		// Index in TAB_LIST of next tab stop to examine.
		mut tab_index := 0
		// If true, the first pending blank came just before a tab stop.  */
		mut one_blank_before_tab_stop := false
		// If true, the previous input character was a blank.  This is
		// initially true, since initial strings of blanks are treated
		// as if the line was preceded by a blank.
		mut prev_blank := true
		// Number of pending columns of blanks.
		mut pending := 0
		// Convert a line of text.

		for mut c in line.runes() {
			if convert {
				blank := c == ` ` || c == `\t`
				if blank {
					mut last_tab := false
					next_tab_column, tab_index, last_tab = get_next_tab_column(column,
						tab_index, mut app)
					// println('${next_tab_column} ${tab_index} ${last_tab}')

					if last_tab {
						convert = false
					}
					if convert {
						if next_tab_column < column {
							exit_error('1input line is too long')
						}
						if c == `\t` {
							column = next_tab_column

							if pending > 0 {
								pending_blank[0] = `\t`
							}
						} else {
							column += 1
							if !(prev_blank && column == next_tab_column) {
								// It is not yet known whether the pending
								// blanks will be replaced by tabs.
								if column == next_tab_column {
									one_blank_before_tab_stop = true
								}
								pending_blank[pending] = c
								pending += 1
								prev_blank = true
								continue
							}

							// Replace the pending blanks by a tab or two.
							c = `\t`
							pending_blank[0] = c
						}

						// Discard pending blanks, unless it was a single
						// blank just before the previous tab stop.
						pending = if one_blank_before_tab_stop { 1 } else { 0 }
					}
				} else if c == `\b` {
					// Go back one column, and force recalculation of the
					// next tab stop.
					column -= if column > 0 { 1 } else { 0 }
					next_tab_column = column
					tab_index -= if tab_index > 0 { 1 } else { 0 }
				} else {
					column += 1
					if column == 0 {
						exit_error('1input line is too long')
					}
				}

				if pending > 0 {
					if pending > 1 && one_blank_before_tab_stop {
						pending_blank[0] = `\t`
					}
					print(pending_blank[..pending].string())
					pending = 0
					one_blank_before_tab_stop = false
				}

				prev_blank = blank
				convert = convert && (app.convert_entire_line || blank)
			}

			if c < 0 {
				return
			}

			print(c)
		}

		println('')
	}
}

fn get_next_tab_column(column int, tab_index_arg int, mut app App) (int, int, bool) {
	mut tab_index := tab_index_arg

	// single tab-size - return multiples of it
	if app.tab_size > 0 {
		return column + (app.tab_size - column % app.tab_size), tab_index, false
	}

	// multiple tab-sizes - iterate them until the tab
	// position is beyondthe current input column.
	for ; tab_index < app.first_free_tab; tab_index++ {
		tab := app.tab_list[tab_index]
		if column < tab {
			return tab, tab_index, false
		}
	}

	// relative last tab - return multiples of it
	if app.extend_size > 0 {
		return column + (app.extend_size - column % app.extend_size), tab_index, false
	}

	// incremental last tab - add increment_size to the previous tab stop
	if app.increment_size > 0 {
		end_tab := app.tab_list[app.first_free_tab - 1]
		return column + (app.increment_size - ((column - end_tab) % app.increment_size)), tab_index, false
	}

	return 0, tab_index, true
}

// Check that the list of tab stops TABS, with ENTRIES
// entries,contains only nonzero, ascending values.
fn validate_tab_stops(tabs []int, entries int, app App) {
	mut prev_tab := 0

	for i := 0; i < entries; i++ {
		if tabs[i] == 0 {
			exit_error('tab size cannot be 0')
		}
		if tabs[i] <= prev_tab {
			exit_error('tab sizes must be ascending')
		}
		prev_tab = tabs[i]
	}

	if app.increment_size > 0 && app.extend_size > 0 {
		exit_error("'/' specifier is mutually exclusive with '+'")
	}
}

// Called after all command-line options have been parsed,
//   and add_tab_stop/parse_tab_stops have been called.
//   Will validate the tab-stop values,
//     and set the final values to:
//     tab-stops = 8 (if no tab-stops given on command line)
//     tab-stops = N (if value N specified as the only value).
//     tab-stops = distinct values given on command line (if multiple values given).
fn finalize_tab_stops(mut app App) {
	validate_tab_stops(app.tab_list, app.first_free_tab, app)

	if app.first_free_tab == 0 {
		if app.max_column_width == app.extend_size {
			if app.extend_size > 0 {
				app.tab_size = app.extend_size
			} else if app.increment_size > 0 {
				app.tab_size = app.increment_size
			} else {
				app.tab_size = 8
			}
		}
		app.max_column_width = app.tab_size
	} else if app.first_free_tab == 1 && app.extend_size == 0 && app.increment_size == 0 {
		app.tab_size = app.tab_list[0]
	} else {
		app.tab_size = 0
	}
}

// Add the comma or blank separated list of tab stops STOPS
// to the list of tab stops.
fn parse_tab_stops(stops []u8, mut app App) {
	mut have_tabval := false
	mut tabval := 0
	mut extend_tabval := false
	mut increment_tabval := false
	// mut num_start := []u8{}
	mut ok := true

	for stop in stops {
		if stop == `,` || stop == ` ` {
			if have_tabval {
				if extend_tabval {
					if !set_extend_size(tabval, mut app) {
						ok = false
						break
					}
				} else if increment_tabval {
					if set_increment_size(tabval, mut app) {
						ok = false
						break
					}
				} else {
					add_tab_stop(tabval, mut app)
				}
			}
			have_tabval = false
		} else if stop == `/` {
			if have_tabval {
				exit_error("'/' specifier not at start of number: %s")
				ok = false
			}
			extend_tabval = true
			increment_tabval = false
		} else if stop == `+` {
			if have_tabval {
				exit_error("'+' specifier not at start of number: %s")
				ok = false
			}
			increment_tabval = true
			extend_tabval = false
		} else if stop.is_digit() {
			if !have_tabval {
				tabval = 0
				have_tabval = true
			}
			tabval += tabval * 10 + int(stop - `0`)
		} else {
			exit_error('tab size contains invalid character(s): %s')
			ok = false
			break
		}
	}

	if ok && have_tabval {
		if extend_tabval {
			ok = set_extend_size(tabval, mut app) && ok
		} else if increment_tabval {
			ok = set_increment_size(tabval, mut app) && ok
		} else {
			add_tab_stop(tabval, mut app)
		}
	}

	if !ok {
		exit_error('bonk')
	}
}

fn set_extend_size(tabval int, mut app App) bool {
	mut ok := true
	if app.extend_size > 0 {
		exit_error("'/' specifier only allowed with the last value")
		ok = false
	}
	app.extend_size = tabval
	return ok
}

fn set_increment_size(tabval int, mut app App) bool {
	mut ok := true
	if app.increment_size > 0 {
		exit_error("'+' specifier only allowed with the last value")
		ok = false
	}
	app.increment_size = tabval
	return ok
}

// Add tab stop TABVAL to the end of 'tab_list'.
fn add_tab_stop(tabval int, mut app App) {
	prev_column := if app.first_free_tab > 0 { app.tab_list[app.first_free_tab - 1] } else { 0 }
	column_width := if prev_column <= tabval { tabval - prev_column } else { 0 }

	if app.first_free_tab == app.n_tabs_allocated {
		app.tab_list << tabval
		app.first_free_tab += 1
		app.n_tabs_allocated += 1
	}
	if app.max_column_width < column_width {
		if 0xffff < column_width {
			exit_error('tabs are too far apart')
		}
		app.max_column_width = column_width
	}
}
