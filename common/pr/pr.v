module pr

pub struct Settings {
pub mut:
	// Page layout
	page_length  int = 66
	page_width   int = 72
	header_text  string
	no_header    bool // -t
	number_lines bool // -n
	number_width int = 5
	double_space bool // -d
	offset       int  // -o
	columns      int = 1
	across       bool   // -a
	merge        bool   // -m
	col_sep      string // -s
	form_feeds   bool   // -F / -f
	first_number int = 1
	// Files
	operands    []string
	width_given bool
}

// run formats the operands and returns the text main should print.
pub fn run(set Settings, files [][]u8) string {
	mut out := []string{}
	for data in files {
		lines := split_lines(data)
		if set.number_lines {
			for l in numbered(lines, set) {
				out << l
				if set.double_space {
					out << ''
				}
			}
		} else {
			for l in lines {
				out << l
				if set.double_space {
					out << ''
				}
			}
		}
	}
	mut text := out.join('\n')
	if set.offset > 0 {
		// -o indents every line by the given number of columns.
		pad := ' '.repeat(set.offset)
		lines2 := text.split('\n')
		mut shifted := []string{cap: lines2.len}
		for l in lines2 {
			shifted << pad + l
		}
		text = shifted.join('\n')
	}
	return text
}

fn split_lines(data []u8) []string {
	if data.len == 0 {
		return []string{}
	}
	mut s := data.bytestr()
	// A trailing newline is a line terminator, not a final empty line.
	if s.ends_with('\n') {
		s = s[..s.len - 1]
	}
	return s.split('\n')
}

// numbered prefixes each line with its number, right-justified in the GNU
// width of five, then a tab, then the line itself.
fn numbered(lines []string, set Settings) []string {
	mut out := []string{cap: lines.len}
	mut n := set.first_number
	for l in lines {
		out << '${n:5}\t${l}'
		n++
	}
	return out
}

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut operands := []string{}

	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--' {
			operands << args[i + 1..]
			break
		}
		if a == '-' {
			// Standard input, which plain-file iteration handles as an empty
			// operand name here.
			operands << a
			continue
		}
		if !a.starts_with('-') {
			operands << a
			continue
		}
		if a.starts_with('--') {
			name := a.all_before('=')
			val := a.all_after('=')
			has_val := a.contains('=')
			match name {
				'--omit-header' {
					s.no_header = true
				}
				'--pages' {}
				'--length' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.page_length = int_value('l PAGE_LENGTH', v)
				}
				'--width' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.page_width = int_value('w PAGE_WIDTH', v)
					s.width_given = true
				}
				'--first-line-number' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.first_number = int_value('N FIRST_LINE_NUMBER', v)
				}
				'--indent' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.offset = int_value('o INDENT', v)
				}
				'--column' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.columns = int_value('COLUMN', v)
				}
				'--across' {
					s.across = true
				}
				'--double-space' {
					s.double_space = true
				}
				'--number-lines' {
					s.number_lines = true
				}
				'--form-feed' {
					s.form_feeds = true
				}
				'--merge' {
					s.merge = true
				}
				'--separator' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.col_sep = v
				}
				'--header' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.header_text = v
				}
				else {
					common_exit("unrecognized option '${a}'")
				}
			}
			continue
		}

		mut j := 1
		for j < a.len {
			c := a[j]
			match c {
				`t` {
					s.no_header = true
				}
				`n` {
					s.number_lines = true
				}
				`d` {
					s.double_space = true
				}
				`a` {
					s.across = true
				}
				`m` {
					s.merge = true
				}
				`F`, `f` {
					s.form_feeds = true
				}
				`r` {}
				`p` {}
				`J` {}
				`v` {}
				`b` {}
				`e` {}
				`i` {}
				`N` {
					v, next := take_short(args, i, a, j)
					i = next
					s.first_number = int_value('N FIRST_LINE_NUMBER', v)
					j = a.len
					continue
				}
				`o` {
					v, next := take_short(args, i, a, j)
					i = next
					s.offset = int_value('o INDENT', v)
					j = a.len
					continue
				}
				`l` {
					v, next := take_short(args, i, a, j)
					i = next
					s.page_length = int_value('l PAGE_LENGTH', v)
					j = a.len
					continue
				}
				`w` {
					v, next := take_short(args, i, a, j)
					i = next
					s.page_width = int_value('w PAGE_WIDTH', v)
					s.width_given = true
					j = a.len
					continue
				}
				`h` {
					v, next := take_short(args, i, a, j)
					i = next
					s.header_text = v
					j = a.len
					continue
				}
				`s` {
					// -s takes at most one separator character.
					rest := a[j + 1..]
					s.col_sep = rest
					j = a.len
					continue
				}
				`0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9` {
					// A leading digit is a column count, since -N is not a flag.
					mut n := 0
					for k := j; k < a.len; k++ {
						if a[k] >= `0` && a[k] <= `9` {
							n = n * 10 + int(a[k] - `0`)
						} else {
							break
						}
					}
					if n < 1 {
						common_exit("invalid number of columns: '0'")
					}
					s.columns = n
					j = a.len
					continue
				}
				`-` {
					j++
					continue
				}
				else {
					common_exit("invalid option -- '${c.ascii_str()}'")
				}
			}
			j++
		}
	}

	s.operands = operands
	return s
}

fn int_value(what string, v string) int {
	mut n := 0
	for c in v.bytes() {
		if c < `0` || c > `9` {
			common_exit("'-${what}' invalid number of ${label_for(what)}: ‘${v}’")
		}
		n = n * 10 + int(c - `0`)
	}
	if n == 0 {
		common_exit("'-${what}' invalid number of ${label_for(what)}: ‘${v}’: Numerical result out of range")
	}
	return n
}

fn label_for(what string) string {
	return if what == 'w PAGE_WIDTH' { 'characters' } else { 'lines' }
}

fn take_short(args []string, i int, a string, j int) (string, int) {
	rest := a[j + 1..]
	if rest != '' {
		return rest, i
	}
	if i + 1 >= args.len {
		common_exit("option requires an argument -- '${a[j].ascii_str()}'")
	}
	return args[i + 1], i + 1
}

fn take_value(args []string, i int, inline_val string, has_val bool, name string) (string, int) {
	if has_val {
		return inline_val, i
	}
	if i + 1 >= args.len {
		common_exit("option '${name}' requires an argument")
	}
	return args[i + 1], i + 1
}

fn common_exit(msg string) {
	eprintln('pr: ${msg}')
	exit(1)
}
