module main

import common
import flag
import os
import term

const app_name = 'ls'
const app_version = '0.1'
const current_dir = ['.']

const when_always = 'always'
const when_never = 'never'
const when_auto = 'auto'

@[version: app_version]
@[name: app_name]
struct Options {
mut:
	//
	// flags
	all                   bool   @[long: 'all'; short: 'a'; xdoc: 'do not ignore entries starting with .']
	almost_all            bool   @[long: 'almost-all'; short: 'A'; xdoc: 'do not list implied . and ..'] // default is to not list, not used
	blocked_output        bool   @[xdoc: 'blank line every 5 rows']
	checksum              string @[xdoc: 'show file checksum (md5, sha1, sha224, sha256, sha512, blake2b)']
	list_by_columns       bool   @[only: 'C'; xdoc: 'list entries by columns']
	colorize              string = when_never @[long: 'color'; xdoc: 'color the output <string> (WHEN); more info below']
	long_no_owner         bool   @[only: 'g'; xdoc: 'like -l, but do not list owner']
	dirs_first            bool   @[only: 'group-directories-first'; xdoc: 'group directories before files; can be augmented with a --sort option, but any use of --sort=none (-U) disables grouping']
	icons                 bool   @[xdoc: 'show file icon (requires nerd fonts)']
	no_count              bool   @[xdoc: 'hide file/dir counts']
	no_date               bool   @[xdoc: 'hide data (modified)']
	no_dim                bool   @[xdoc: 'hide shading; useful for light backgrounds']
	no_group_name         bool   @[long: 'no-group'; short: 'G'; xdoc: 'in a long listing, don\'t print group names']
	no_hard_links         bool   @[xdoc: 'hide hard links count']
	no_owner_name         bool   @[only: 'no_owner'; xdoc: 'hide owner name']
	no_permissions        bool   @[xdoc: 'hide permissions']
	no_size               bool   @[xdoc: 'hide file size']
	no_wrap               bool   @[xdoc: 'do not wrap long lines']
	size_kb               bool   @[long: 'human-readable'; short: 'h'; xdoc: 'with -l and -s, print sizes like 1K 234M 2G etc.']
	header                bool   @[xddoc: 'show column headers (implies -l)']
	size_ki               bool   @[long: 'si'; xdoc: 'likewise, but use powers of 1000 not 1024']
	inode                 bool   @[long: 'inode'; short: 'i'; xdoc: 'print the index number of each file']
	long_format           bool   @[only: 'l'; xdoc: 'use a long listing format']
	with_commas           bool   @[only: 'm'; xdoc: 'fill width with a comma separated list of entries']
	long_no_group         bool   @[only: 'o'; xdoc: 'like -l, but do not list group information']
	octal_permissions     bool   @[xdoc: 'show as permissions octal number']
	only_dirs             bool   @[xdoc: 'list only directories']
	only_files            bool   @[xdoc: 'list only files']
	dir_indicator         bool   @[long: 'indicator-style'; short: 'p'; xdoc: 'append / indicator to directories']
	quote                 bool   @[long: 'quote-name'; short: 'Q'; xdoc: 'enclose entry names in double quotes']
	sort_reverse          bool   @[only: 'r'; xdoc: 'reverse order while sorting']
	relative_path         bool   @[xdoc: 'show relative path']
	recursive             bool   @[only: 'R'; xdoc: 'list subdirectories recursively']
	recursion_depth       int    @[xdoc: 'limit depth of recursion']
	sort_size             bool   @[only: 'S'; xdoc: 'sort by file size, largest first']
	sort_by               string @[only: 'sort'; xdoc: 'sort by WORD instead of name; none (-U), size (-S), time(-t), version (-v), extension (-X), width']
	sort_time             bool   @[only: 't'; xdoc: 'sort by time, newest first']
	table_format          bool   @[xdoc: 'add borders to long listing format (implies -l)']
	accessed_date         bool   @[only: 'time-accessed'; xdoc: 'show last accessed time']
	changed_date          bool   @[only: 'time-changed'; xdoc: 'show last changed time']
	time_iso              bool   @[xdoc: 'show time in iso format']
	time_compact          bool   @[xdoc: 'show time in compact format']
	time_compact_with_day bool   @[xdoc: 'show time in compact format with week day']
	sort_none             bool   @[only: 'U'; xdoc: 'do not sort; list entries in directory order']
	sort_natural          bool   @[only: 'v'; xdoc: 'natural sort of (version) numbers within text']
	sort_width            bool   @[ignore]
	width_in_cols         int    @[long: 'width'; short: 'w'; xdoc: 'set output width to <int> (COLS). 0 means no limit']
	list_by_lines         bool   @[only: 'x'; xdoc: 'list entries by lines']
	sort_ext              bool   @[only: 'X'; xdoc: 'sort alphabetically by entry extension']
	one_per_line          bool   @[only: '1'; xdoc: 'list one file per line']
	//
	// from ls colors
	style_di Style @[ignore]
	style_fi Style @[ignore]
	style_ln Style @[ignore]
	style_ex Style @[ignore]
	style_pi Style @[ignore]
	style_bd Style @[ignore]
	style_cd Style @[ignore]
	style_so Style @[ignore]
	//
	// help
	//
	show_help    bool @[long: 'help'; xdoc: 'display this help and exit']
	show_version bool @[long: 'version'; xdoc: 'show version and exit']
}

fn get_args() (Options, []string) {
	mut options, files := flag.to_struct[Options](os.args, skip: 1) or { panic(err) }

	if options.show_help {
		doc := flag.to_doc[Options](
			description: 'Usage: ls [OPTION]... FILE...\n' +
				'List information about the FILEs (the current directory by default).'
			// vfmt off
			footer:
				'\n' +
				"The WHEN argument defaults to 'always' and can also be 'auto' or 'never'.\n" +
				'\n' +
				'Using color to distinguish file types is disabled both by default and\n' +
				'with --color=never. With --color=auto, ls emits color codes only when\n' +
				'standard output is connected to a terminal. The LS_COLORS environment\n' +
				'variable can change the settings. Use the dircolors command to set it.\n' +
				'\n' +
				'Exit status:\n' +
				' 0  if OK,\n' +
				' 1  if minor problems (e.g., cannot access subdirectory),\n' +
				' 2  if serious trouble (e.g., cannot access command-line argument).\n' +
				common.coreutils_footer()
			// vfmt on
		) or { panic(err) }
		println(doc)
		exit(0)
	}

	if options.show_version {
		println('${app_name} ${app_version}\n${common.coreutils_footer()}')
		exit(0)
	}

	if files.len > 0 && files.any(it.starts_with('-')) {
		eexit('The following flags could not be mapped to any fields: ${files.filter(it.starts_with('-'))}')
	}

	if options.long_no_group {
		options.long_format = true
		options.no_group_name = true
	}

	if options.long_no_owner {
		options.long_format = true
		options.no_owner_name = true
	}

	if options.table_format || options.header || options.checksum.len > 0 || options.no_count
		|| options.no_date || options.no_permissions || options.no_size || options.no_count
		|| options.octal_permissions {
		options.long_format = true
	}

	match options.sort_by {
		'none' { options.sort_none = true }
		'size' { options.sort_size = true }
		'time' { options.sort_time = true }
		'width' { options.sort_width = true }
		'version' { options.sort_natural = true }
		'extension' { options.sort_ext = true }
		else {}
	}

	options.colorize = match options.colorize {
		// vfmt off
		when_never  { when_never }
		when_always { when_always }
		when_auto   { if term.can_show_color_on_stdout() { when_always } else { when_never } }
		else        { eexit('invalid --color=argument (always, never, auto') }
		// vfmt on
	}

	style_map := make_style_map()
	options.style_bd = style_map['bd']
	options.style_cd = style_map['cd']
	options.style_di = style_map['di']
	options.style_ex = style_map['ex']
	options.style_fi = style_map['fi']
	options.style_ln = style_map['ln']
	options.style_pi = style_map['pi']
	options.style_so = style_map['so']

	if files.filter(!it.starts_with('-')).len == 0 {
		return options, current_dir
	}

	return options, files
}

@[noreturn]
fn eexit(msg string) {
	if msg.len > 0 {
		eprintln('${app_name}: ${msg}')
	}
	eprintln("Try '${app_name} --help' for more information.")
	exit(2)
}
