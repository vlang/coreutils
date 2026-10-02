import term
import os

struct Style {
	fg   fn (string) string = no_color
	bg   fn (string) string = no_color
	bold bool
	dim  bool
	ul   bool
}

const no_style = Style{}

const unknown_style = Style{
	fg: fgf('30')
	bg: bgf('43')
}
const dim_style = Style{
	dim: true
}

const di_style = Style{
	bold: true
	fg:   fgf('36') // cyan
}

const fi_style = Style{
	fg: fgf('32') // green
}

const ln_style = Style{
	bold: true
	fg:   fgf('34') // magenta
}

const ex_style = Style{
	bold: true
	fg:   fgf('31') // red
}

const so_style = Style{
	fg: fgf('32') // green
}

const pi_style = Style{
	fg: fgf('33') // orange
}

const bd_style = Style{
	fg: fgf('34')
	bg: bgf('46')
}

const cd_style = Style{
	fg: fgf('34')
	bg: bgf('43')
}

fn style_string(s string, style Style, options Options) string {
	if options.colorize == when_never {
		return s
	}
	mut out := style.fg(s)
	if style.bg != no_color {
		out = style.bg(out)
	}
	if style.bold {
		out = term.bold(out)
	}
	if style.ul {
		out = term.underline(out)
	}
	if style.dim {
		out = term.dim(out)
	}
	return out
}

fn make_style_map() map[string]Style {
	mut style_map := map[string]Style{}

	// start with some defaults
	style_map['di'] = di_style
	style_map['fi'] = fi_style
	style_map['ln'] = ln_style
	style_map['ex'] = ex_style
	style_map['so'] = so_style
	style_map['pi'] = pi_style
	style_map['bd'] = bd_style
	style_map['cd'] = cd_style

	// example LS_COLORS
	// di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43
	ls_colors := os.getenv('LS_COLORS')
	fields := ls_colors.split(':')

	for field in fields {
		id_codes := field.split('=')
		if id_codes.len == 2 {
			id := id_codes[0]
			style := make_style(id_codes[1])
			style_map[id] = style
		}
	}
	return style_map
}

fn make_style(ansi string) Style {
	mut bold := false
	mut ul := false
	mut fg := no_color
	mut bg := no_color

	codes := ansi.split(';')

	for code in codes {
		match code {
			'0' { bold = false }
			'1' { bold = true }
			'4' { ul = true }
			'31' { fg = fgf(code) }
			'32' { fg = fgf(code) }
			'33' { fg = fgf(code) }
			'34' { fg = fgf(code) }
			'35' { fg = fgf(code) }
			'36' { fg = fgf(code) }
			'37' { fg = fgf(code) }
			'40' { bg = bgf(code) }
			'41' { bg = bgf(code) }
			'42' { bg = bgf(code) }
			'43' { bg = bgf(code) }
			'44' { bg = bgf(code) }
			'45' { bg = bgf(code) }
			'46' { bg = bgf(code) }
			'47' { bg = bgf(code) }
			'90' { fg = fgf(code) }
			'91' { fg = fgf(code) }
			'92' { fg = fgf(code) }
			'93' { fg = fgf(code) }
			'94' { fg = fgf(code) }
			'95' { fg = fgf(code) }
			'96' { fg = fgf(code) }
			'100' { bg = bgf(code) }
			'101' { bg = bgf(code) }
			'102' { bg = bgf(code) }
			'103' { bg = bgf(code) }
			'104' { bg = bgf(code) }
			'105' { bg = bgf(code) }
			'106' { bg = bgf(code) }
			else {}
		}
	}

	return Style{
		fg:   fg
		bg:   bg
		bold: bold
		ul:   ul
	}
}

fn no_color(s string) string {
	return s
}

fn fgf(code string) fn (string) string {
	return fn [code] (msg string) string {
		return term.format(msg, code, '39')
	}
}

fn bgf(code string) fn (string) string {
	return fn [code] (msg string) string {
		return term.format(msg, code, '49')
	}
}
