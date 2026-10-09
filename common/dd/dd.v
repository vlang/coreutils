module dd

import os

pub enum StatusMode {
	full
	noxfer
	none
}

pub struct Settings {
pub mut:
	ifile     string
	ofile     string
	bs        u64 = 512
	ibs       u64
	obs       u64
	ibs_set   bool
	obs_set   bool
	cbs       u64 = 128
	cbs_set   bool
	count     u64
	count_set bool
	skip      u64
	seek      u64
	status    StatusMode = .full
	conv      []string
	iflag     []string
	oflag     []string
}

// conv reports whether the given conversion was requested.
pub fn (s &Settings) conv_has(name string) bool {
	return name in s.conv
}

pub fn (s &Settings) iflag_has(name string) bool {
	return name in s.iflag
}

pub fn (s &Settings) oflag_has(name string) bool {
	return name in s.oflag
}

pub struct Report {
pub mut:
	records_in  u64
	partial_in  u64
	records_out u64
	partial_out u64
	bytes       u64
}

// run performs the copy and returns the report plus an exit code.
pub fn run(set Settings) (Report, int) {
	mut in_data := read_input(set) or {
		return Report{}, 1
	}
	mut data := in_data

	// skip and seek are counted in blocks, unless the *_bytes flags turn them
	// into byte offsets.
	mut ibs := set.ibs
	if !set.ibs_set {
		ibs = set.bs
	}
	mut obs := set.obs
	if !set.obs_set {
		obs = set.bs
	}
	if ibs == 0 {
		ibs = 512
	}
	if obs == 0 {
		obs = 512
	}

	mut start := u64(0)
	if set.skip > 0 {
		if set.iflag_has('skip_bytes') {
			start = set.skip
		} else {
			start = set.skip * ibs
		}
		if start > data.len {
			start = u64(data.len)
		}
	}

	mut out_offset := u64(0)
	if set.seek > 0 {
		if set.oflag_has('seek_bytes') {
			out_offset = set.seek
		} else {
			out_offset = set.seek * obs
		}
	}

	// count limits either records or bytes, per iflag=count_bytes. With no
	// count operand the whole remainder is used.
	mut end := u64(data.len)
	if set.count_set {
		mut limit := u64(0)
		if set.iflag_has('count_bytes') {
			limit = set.count
		} else {
			limit = set.count * ibs
		}
		end = start + limit
		if end > data.len {
			end = u64(data.len)
		}
	}
	if start > data.len {
		return Report{}, 0
	}
	data = data[int(start)..int(end)]

	// conv=sync pads the final short input block out to a whole one.
	if set.conv_has('sync') && data.len % int(ibs) != 0 {
		pad := int(ibs) - (data.len % int(ibs))
		for _ in 0 .. pad {
			data << 0
		}
	}

	// The record-level conversions all operate on the whole buffer here,
	// because the byte conversions dd applies are order-independent.
	if set.conv_has('lcase') {
		data = map_case(data, false)
	}
	if set.conv_has('ucase') {
		data = map_case(data, true)
	}
	if set.conv_has('swab') {
		data = swap_pairs(data, ibs)
	}
	// conv=ascii/ebcdic and friends need cbs and are not implemented; the
	// caller rejects them before reaching this point.

	mut report := Report{
		bytes: u64(data.len)
	}
	// Full records are counted from the input block size, so a short final
	// block is reported as partial.
	if data.len > 0 {
		report.records_in = u64(data.len) / ibs
		report.partial_in = u64(data.len) % ibs
	}

	code := write_output(data, set, out_offset, mut report)
	return report, code
}

fn map_case(data []u8, upper bool) []u8 {
	mut out := []u8{cap: data.len}
	for c in data {
		if upper {
			if c >= `a` && c <= `z` {
				out << c - 32
			} else {
				out << c
			}
		} else {
			if c >= `A` && c <= `Z` {
				out << c + 32
			} else {
				out << c
			}
		}
	}
	return out
}

fn swap_pairs(data []u8, block u64) []u8 {
	mut out := []u8{cap: data.len}
	// swab exchanges the two bytes of each pair *within a block*, so with
	// bs=1 there is nothing to exchange and the data passes through.
	if block < 2 {
		return data.clone()
	}
	mut i := 0
	for i + 1 < data.len {
		out << data[i + 1]
		out << data[i]
		i += 2
	}
	for i < data.len {
		out << data[i]
		i++
	}
	return out
}

fn read_input(set Settings) ?[]u8 {
	if set.ifile == '' || set.ifile == '-' {
		mut out := []u8{}
		mut chunk := []u8{len: 64 * 1024}
		mut f := os.stdin()
		for {
			n := f.read(mut chunk) or { break }
			if n == 0 {
				break
			}
			out << chunk[..n]
		}
		return out
	}
	if !os.exists(set.ifile) {
		report_error(set, "failed to open '${set.ifile}': No such file or directory")
		return none
	}
	return os.read_file_array(set.ifile)
}

fn write_output(data []u8, set Settings, out_offset u64, mut report Report) int {
	if set.ofile == '' || set.ofile == '-' {
		unsafe {
			C.write(1, data.data, u64(data.len))
		}
		report.records_out = report.records_in
		report.partial_out = report.partial_in
		return 0
	}

	exists := os.exists(set.ofile)
	if set.conv_has('excl') && exists {
		report_error(set, "failed to open '${set.ofile}': File exists")
		return 1
	}
	if set.conv_has('nocreat') && !exists {
		report_error(set, "failed to open '${set.ofile}': No such file or directory")
		return 1
	}

	mut f := if exists && set.conv_has('notrunc') {
		os.open_file(set.ofile, 'r+') or {
			report_error(set, "failed to open '${set.ofile}': ${err}")
			return 1
		}
	} else {
		os.create(set.ofile) or {
			report_error(set, "failed to open '${set.ofile}': ${err}")
			return 1
		}
	}
	if out_offset > 0 {
		f.seek(i64(out_offset), .start) or {}
	}
	f.write(data) or {
		f.close()
		report_error(set, 'writing to ${set.ofile}: ${err}')
		return 1
	}
	f.close()
	report.records_out = report.records_in
	report.partial_out = report.partial_in
	return 0
}

fn report_error(set Settings, msg string) {
	if set.status == .none {
		return
	}
	eprintln('dd: ${msg}')
}

fn C.write(fd i64, buf voidptr, count u64) i64
