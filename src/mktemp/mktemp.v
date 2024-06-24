import os
import arrays
import rand

const retries = 10

fn main() {
	options := get_options()
	println(mktemp(options))
}

fn mktemp(options Options) string {
	dir := match true {
		options.tmp_dir == '' && options.templates.len == 0 { os.temp_dir() }
		options.tmp_dir == '' { '.' }
		else { options.tmp_dir }
	}
	template := if options.templates.len == 1 { options.templates[0] } else { 'tmp.XXXXXXXXXX' }
	return match options.directory {
		true { temp_dir(dir, template, options) or { exit_notify(err.msg(), options) } }
		else { temp_file(dir, template, options) or { exit_notify(err.msg(), options) } }
	}
}

fn temp_file(dir_name string, template string, options Options) !string {
	mut dir := dir_name
	os.ensure_folder_is_writable(dir) or { return error_for_temporary_file(@FN, dir) }
	dir = dir.trim_right(os.path_separator)
	for retry := 0; retry < retries; retry++ {
		name := from_template(template)
		path := os.join_path(dir, name)
		if os.exists(path) {
			continue
		}
		if options.dry_run {
			return path
		}
		mut file := os.create(path) or { continue }
		file.close()
		return path
	}
	return error_for_temporary_file(@FN, dir)
}

fn temp_dir(dir_name string, template string, options Options) !string {
	mut dir := dir_name
	os.ensure_folder_is_writable(dir) or { return error_for_temporary_folder(@FN, dir) }
	dir = dir.trim_right(os.path_separator)
	for retry := 0; retry < retries; retry++ {
		name := from_template(template)
		path := os.join_path(dir, name)
		if os.exists(path) {
			continue
		}
		if options.dry_run {
			return path
		}
		os.mkdir_all(path) or { continue }
		if os.is_dir(path) && os.exists(path) {
			os.ensure_folder_is_writable(path) or { return error_for_temporary_folder(@FN, dir) }
			return path
		}
	}
	return error_for_temporary_folder(@FN, dir)
}

fn error_for_temporary_folder(fn_name string, d string) !string {
	return error('${fn_name} could not create temporary directory "${d}". Ensure you have write permissions for it.')
}

fn error_for_temporary_file(fn_name string, d string) !string {
	return error('${fn_name} unable to create temporary file in "${fn_name}". Ensure write permissions.')
}

fn from_template(template string) string {
	parts := chunks(template)
	if !parts.any(it.starts_with('X')) {
		exit_error("TEMPLATE must contain three consecutive X's'")
	}
	name := arrays.fold[string, string](parts, '', fn (a string, c string) string {
		return a + if c.len > 2 && c.starts_with('X') { random_file_ascii(c.len) } else { c }
	})
	return name
}

enum ChunkState {
	unknown
	alpha_num
	xxx
}

fn chunks(template string) []string {
	mut start := 0
	mut parts := []string{}
	mut state := ChunkState.unknown
	ta := template.runes()

	for i, c in ta {
		if c == `X` {
			if state == .alpha_num {
				parts << ta[start..i].string()
				start = i
			}
			state = .xxx
		} else {
			if state == .xxx {
				parts << ta[start..i].string()
				start = i
			}
			state = .alpha_num
		}
	}

	if start < ta.len - 1 {
		parts << ta[start..].string()
	}
	return parts
}

// Characters restricted to legal file chars
fn random_file_ascii(len int) string {
	mut ascii := ''
	alpha := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWYZ'.bytes()
	alpha_num := '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWYZ'.bytes()
	for i := 0; i < len; i++ {
		elements := if i == 0 { alpha } else { alpha_num }
		b := rand.element[u8](elements) or { u8(35) }
		ascii += b.ascii_str()
	}
	return ascii
}
