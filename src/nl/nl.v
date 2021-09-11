module main

import common
import os
import io
import strings
import strconv
import regex

//// Compile options for compatibility ////
// all_line_separator := false		// false:GNU, true:BSD
// remove_delimiter_line := false	// false:GNU, true:BSD
// one_delimiter_posix := false		// false:GNU, true:BSD
// fixed_width := false				// false:GNU, true:BSD

const (
	app_name        = 'nl'
	app_description = 'Line numbering filter'
)

enum Section {
	header
	body
	footer
	text
}

enum Format {
	ln
	rn
	rz
}

enum Style {
	all
	nonempty
	nonumber
	regex
}

struct Settings {
mut:
	ini_lno    i64    // -v
	inc_lno    i64    // -i
	width      int    // -w
	separator  string // -s
	reset_lno  bool   // -p
	join_blank int    // -l
	format     Format // -n
	styles     map[Section]Style    // -b, -h, -f
	delimiters map[Section]string   // -d
	res        map[Section]regex.RE // -b pRE, -h pRE, -f pRE
}

///===================================================================///
///                       Main Logic                                  ///
///===================================================================///

fn main() {
	settings, fnames := args() ?
	streams := open_stream(fnames)
	nl(settings, streams)
}

fn nl(settings Settings, streams []os.File) {
	mut lineno := settings.ini_lno
	mut section := Section.body
	mut overflow := false
	mut blanks := 0
	mut skip := false
	mut prefix := ''

	f_lno := format_lineno(settings.format, settings.width)

	//// Compile options, default is GNU-compatible behavior ////
	// In BSD, a separator is added to all lines. This is not POSIX compatible.
	mut skip_prefix := '' // Why? The variable declaration in ifdef blocks is compile errors.
	$if all_line_separator ? {
		skip_prefix = strings.repeat(` `, settings.width) + settings.separator
	} $else {
		skip_prefix = strings.repeat(` `, settings.width + settings.separator.len)
	}

	for stream in streams {
		mut file := stream
		mut br := io.new_buffered_reader(io.BufferedReaderConfig{ reader: file })

		for {
			mut line := br.read_line() or { break }
			mut next := check_section_delimiter(settings, line)

			match next {
				.header, .body, .footer {
					section = next
					blanks = 0

					if settings.reset_lno {
						lineno = settings.ini_lno
					}

					//// Compile options, default is GNU-compatible behavior ////
					// In BSD, delimiter lines are deleted.
					$if remove_delimiter_line ? {
					} $else {
						println('')
					}
				}
				.text {
					if _unlikely_(overflow) {
						common.exit_with_error_message(app_name, 'Line number overflow')
					}

					skip, blanks = check_skip_line(settings.styles[section], settings.res[section],
						settings.join_blank, blanks, line)

					if skip {
						prefix = skip_prefix
					} else {
						prefix = strconv.v_sprintf(f_lno, lineno)

						//// Compile options, default is GNU-compatible behavior ////
						// In BSD, the upper digits are truncated in case of overflow.
						$if fixed_width ? {
							i := prefix.len - settings.width
							if i > 0 {
								prefix = prefix[i..]
							}
						}

						prefix += settings.separator
						overflow = is_overflow_add_i64(lineno, settings.inc_lno)
						lineno += settings.inc_lno
						blanks = 0
					}

					println(prefix + line)
				}
			}
		}
	}
}

///===================================================================///
///                        Helper Functions                           ///
///===================================================================///
fn open_stream(args_fn []string) []os.File {
	mut streams := []os.File{}

	// if there are no files, read from stdin
	fnames := if args_fn.len > 0 { args_fn } else { ['-'] }

	for fname in fnames {
		if fname == '-' {
			// handle stdin like files
			streams << os.stdin()
		} else {
			streams << os.open(fname) or { common.exit_with_error_message(app_name, err.msg) }
		}
	}

	return streams
}

fn check_skip_line(style Style, re regex.RE, join_blank int, prev_blanks int, line string) (bool, int) {
	mut blanks := prev_blanks

	match style {
		.all {
			if line.len == 0 {
				blanks += 1

				if blanks == join_blank {
					return false, 0
				} else {
					return true, blanks
				}
			} else {
				return false, 0
			}
		}
		.nonempty {
			if line.len == 0 {
				return true, 0
			} else {
				return false, 0
			}
		}
		.nonumber {
			return true, 0
		}
		.regex {
			mut r := re // re is immutable
			f, _ := r.find(line)

			if f == -1 {
				return true, 0
			} else {
				return false, 0
			}
		}
	}
}

[inline]
fn format_lineno(format Format, width int) string {
	return match format {
		.rn { '%${width}ld' }
		.ln { '%-${width}ld' }
		.rz { '%0${width}ld' }
	}
}

[inline]
fn check_section_delimiter(settings Settings, line string) Section {
	return match line {
		settings.delimiters[.header] { Section.header }
		settings.delimiters[.body] { Section.body }
		settings.delimiters[.footer] { Section.footer }
		else { Section.text }
	}
}

[inline]
fn is_overflow_add_i64(a i64, b i64) bool {
	// Warning! Unspecified behavior.
	return _unlikely_((a < 0 && b < 0 && (a + b) > 0) || (a > 0 && b > 0 && (a + b) < 0))
}

///===================================================================///
///                                Args                               ///
///===================================================================///
fn args() ?(Settings, []string) {
	mut settings := Settings{}
	mut fnames := ['-']

	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	// -b
	b_style := fp.string('body-numbering', `b`, 't', 'Select the numbering style for lines in the body section (a:all, n:none, t:only no blank, pRE: match for the regular expression)')
	settings.styles[Section.body] = get_style(b_style) or {
		common.exit_with_error_message(app_name, err.msg)
	}
	if settings.styles[Section.body] == .regex {
		settings.res[Section.body] = get_style_regex(b_style) or {
			common.exit_with_error_message(app_name, err.msg)
		}
	}

	// -d
	mut delimiter := fp.string('section-delimiter', `d`, '\\:', 'Set the section delimiter')

	//// Compile options, default is GNU-compatible behavior ////
	// POSIX does not allow a single-character delimiter;
	// if it is specified, the second character remains `:`.
	// Instead of this confusing specification,
	// it should conform to the legacy GNU extension.
	$if one_delimiter_posix ? {
		if delimiter.len == 1 {
			delimiter += ':'
		}
	}

	settings.delimiters[Section.header] = delimiter + delimiter + delimiter
	settings.delimiters[Section.body] = delimiter + delimiter
	settings.delimiters[Section.footer] = delimiter

	// -f
	f_style := fp.string('footer-numbering', `f`, 'n', 'Select the numbering style for lines in the footer section')
	settings.styles[Section.footer] = get_style(f_style) or {
		common.exit_with_error_message(app_name, err.msg)
	}
	if settings.styles[Section.footer] == .regex {
		settings.res[Section.footer] = get_style_regex(f_style) or {
			common.exit_with_error_message(app_name, err.msg)
		}
	}

	// -h
	h_style := fp.string('header-numbering', `h`, 'n', 'Select the numbering style for lines in the header section')
	settings.styles[Section.header] = get_style(h_style) or {
		common.exit_with_error_message(app_name, err.msg)
	}
	if settings.styles[Section.header] == .regex {
		settings.res[Section.header] = get_style_regex(h_style) or {
			common.exit_with_error_message(app_name, err.msg)
		}
	}

	// -i
	settings.inc_lno = fp.string('line-increment', `i`, '1', 'Increment line numbers by number').i64()

	// -l
	settings.join_blank = fp.int('join-blank-lines', `l`, 1, 'Join number consecutive empty lines to be one logical line for numbering')

	// -n
	format := fp.string('number-format', `n`, 'rn', 'Select the line numbering format (ln:left-justified, rn:right-justified, rz:leading-zeros)')
	settings.format = get_format(format) or { common.exit_with_error_message(app_name, err.msg) }

	// -p
	no_renumber := fp.bool('no-renumber', `p`, false, 'Do not reset the line number at the start of each logical page')
	settings.reset_lno = !no_renumber

	// -s
	settings.separator = fp.string('number-separator', `s`, '\t', 'Set strings of separator between the line number and the text line')

	// -v
	settings.ini_lno = fp.string('starting-line-number', `v`, '1', 'Set the initial line number on each logical page').i64()

	// -w
	settings.width = fp.int('number-width', `w`, 6, 'Set number digits for line numbers')

	// files
	fnames = fp.finalize() or { common.exit_with_error_message(app_name, err.msg) }

	return settings, fnames
}

fn get_format(str string) ?Format {
	match str {
		'ln' { return Format.ln }
		'rn' { return Format.rn }
		'rz' { return Format.rz }
		else { return error('Invalid line numbering format: $str') }
	}
}

fn get_style(str string) ?Style {
	match str {
		'a' {
			return Style.all
		}
		't' {
			return Style.nonempty
		}
		'n' {
			return Style.nonumber
		}
		else {
			if str.len > 1 && str[0] == `p` {
				return Style.regex
			} else {
				return error('Invalid line numbering style: $str')
			}
		}
	}
}

fn get_style_regex(str string) ?regex.RE {
	return regex.regex_opt(str[1..]) or { return error('Invalid line numbering style: $str') }
}
