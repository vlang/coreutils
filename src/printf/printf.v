module main

import os
import strings
import strconv

const appname = 'printf'

const version = 'v0.0.1'

const usage = '$appname $version
----------------------------------------------
Usage: printf FORMAT [ARGUMENT]...
   or: printf OPTION

Options:
  --help                   display this help and exit
  --version                output version information and exit'

fn main() {
	match os.args.len {
		1 {
			eprintln(usage)
			exit(1)
		}
		2 {
			match os.args[1] {
				'--help' {
					println(usage)
					exit(0)
				}
				'--version' {
					println('$appname $version')
					exit(0)
				}
				else {}
			}
		}
		else {}
	}

	format, ctrl_c_fmt := apply_controls(os.args[1], false)
	mut args := os.args[2..]
	mut idx := 0
	mut out := ''
	mut ctrl_c_arg := false
	for {
		args = args[idx..]
		out, idx, ctrl_c_arg = v_sprintf(format, args)
		print(out)
		if ctrl_c_fmt || ctrl_c_arg || idx == 0 || args.len <= idx {
			break
		}
	}
}

const control_ch = map{
	`a`: `\a`
	`b`: `\b`
	`e`: `\e`
	`f`: `\f`
	`n`: `\n`
	`r`: `\r`
	`t`: `\t`
	`v`: `\v`
}

fn apply_controls(s string, zero_top bool) (string, bool) {
	mut out := strings.new_builder(s.len)
	mut idx := 0
	for idx < s.len {
		ch := s[idx]
		match ch {
			`\\` {
				idx += 2
				if idx > s.len {
					out.write_b(ch)
					break
				}
				ch2 := s[idx - 1]
				match ch2 {
					`"`, `\\` {
						out.write_b(ch2)
					}
					`a`, `b`, `e`, `f`, `n`, `r`, `t`, `v` {
						out.write_b(control_ch[ch2])
					}
					`c` {
						return out.str(), true
					}
					`0`...`7` {
						if zero_top && ch2 == `0` {
							if idx >= s.len || !s[idx].is_oct_digit() {
								out.write_b(`\0`)
								continue
							}
							idx++
						}
						mut out_ch := byte(0)
						idx--
						for _ in 0 .. 3 {
							num := s[idx] - `0`
							out_ch *= 8
							out_ch += num
							idx++
							if idx >= s.len || !s[idx].is_oct_digit() {
								break
							}
						}
						out.write_b(out_ch)
					}
					`x` {
						if idx >= s.len || !s[idx].is_hex_digit() {
							out.write_string('\\x')
							continue
						}
						mut out_ch := byte(0)
						for _ in 0 .. 2 {
							num := byte(match s[idx] {
								`0`...`9` { s[idx] - `0` }
								`A`...`F` { s[idx] - `A` + 10 }
								`a`...`f` { s[idx] - `a` + 10 }
								else { rune(0) }
							})
							out_ch *= 16
							out_ch += num
							idx++
							if idx >= s.len || !s[idx].is_hex_digit() {
								break
							}
						}
						out.write_b(out_ch)
					}
					`u` {
						if idx >= s.len || !s[idx].is_hex_digit() {
							out.write_string('\\u')
							continue
						}
						mut out_ch := u32(0)
						for _ in 0 .. 4 {
							num := u32(match s[idx] {
								`0`...`9` { s[idx] - `0` }
								`A`...`F` { s[idx] - `A` + 10 }
								`a`...`f` { s[idx] - `a` + 10 }
								else { rune(0) }
							})
							out_ch *= 16
							out_ch += num
							idx++
							if idx >= s.len || !s[idx].is_hex_digit() {
								break
							}
						}
						out.write_string(utf32_to_str(out_ch))
					}
					`U` {
						if idx >= s.len || !s[idx].is_hex_digit() {
							out.write_string('\\U')
							continue
						}
						mut out_ch := u32(0)
						for _ in 0 .. 8 {
							num := u32(match s[idx] {
								`0`...`9` { s[idx] - `0` }
								`A`...`F` { s[idx] - `A` + 10 }
								`a`...`f` { s[idx] - `a` + 10 }
								else { rune(0) }
							})
							out_ch *= 16
							out_ch += num
							idx++
							if idx >= s.len || !s[idx].is_hex_digit() {
								break
							}
						}
						out.write_string(utf32_to_str(out_ch))
					}
					else {
						out.write_string('\\$ch2')
					}
				}
			}
			else {
				out.write_b(ch)
				idx++
			}
		}
	}
	return out.str(), false
}

const unprintables = [
	'\\000',
	'\\001',
	'\\002',
	'\\003',
	'\\004',
	'\\005',
	'\\006',
	'\\a',
	'\\b',
	'\\t',
	'\\n',
	'\\v',
	'\\f',
	'\\r',
	'\\016',
	'\\017',
	'\\020',
	'\\021',
	'\\022',
	'\\023',
	'\\024',
	'\\025',
	'\\026',
	'\\027',
	'\\030',
	'\\031',
	'\\032',
	'\\033',
	'\\034',
	'\\035',
	'\\036',
	'\\037',
]

fn apply_posix_escape(s string) string {
	mut has_unprintable := false
	mut upout := strings.new_builder(s.len)
	for ch in s {
		match ch {
			0...0x1f {
				has_unprintable = true
				upout.write_string(unprintables[ch])
			}
			0x7f {
				has_unprintable = true
				upout.write_string('\\177')
			}
			else {
				upout.write_b(ch)
			}
		}
	}
	return if has_unprintable { '\$\'$upout\'' } else { s.replace_each([
			'|',
			'\\|',
			'&',
			'\\&',
			';',
			'\\;',
			'<',
			'\\<',
			'>',
			'\\>',
			'(',
			'\\(',
			')',
			'\\)',
			'\$',
			'\\\$',
			'`',
			'\\`',
			"'",
			'\\' + "'", // TODO: v must fix this
			'\\',
			'\\\\',
			'"',
			'\\"',
			' ',
			'\\ ',
		]) }
}

// A code below is modded version of vlib/strconv/vprintf.v whose parameter to be an array of string

/*=============================================================================
Copyright (c) 2019-2021 Dario Deledda. All rights reserved.
Use of this source code is governed by an MIT license
that can be found in the LICENSE file.

This file contains string interpolation V functions
=============================================================================*/

enum Char_parse_state {
	start
	norm_char
	field_char
	pad_ch
	len_set_start
	len_set_in
	check_type
	check_float
	check_float_in
	reset_params
}

fn v_sprintf(str string, _pt []string) (string, int, bool) {
	mut pt := _pt.clone()
	mut res := strings.new_builder(pt.len * 16)

	mut i := 0 // main string index
	mut p_index := 0 // parameter index
	mut sign := false // sign flag
	mut allign := strconv.Align_text.right
	mut len0 := -1 // forced length, if -1 free length
	mut len1 := -1 // decimal part for floats
	def_len1 := 6 // default value for len1
	mut pad_ch := byte(` `) // pad char

	// prefix chars for Length field
	mut ch1 := `0` // +1 char if present else `0`
	mut ch2 := `0` // +2 char if present else `0`

	mut status := Char_parse_state.norm_char
	for i < str.len {
		if status == .reset_params {
			sign = false
			allign = .right
			len0 = -1
			len1 = -1
			pad_ch = ` `
			status = .norm_char
			ch1 = `0`
			ch2 = `0`
			continue
		}

		ch := str[i]
		if ch != `%` && status == .norm_char {
			res.write_b(ch)
			i++
			continue
		}
		if ch == `%` && status == .norm_char {
			status = .field_char
			i++
			continue
		}

		// single char, manage it here
		if ch == `c` && status == .field_char {
			v_sprintf_panic(mut pt, p_index, pt.len)
			d1 := byte(pt[p_index].u16())
			res.write_b(d1)
			status = .reset_params
			p_index++
			i++
			continue
		}

		// pointer, manage it here
		if ch == `p` && status == .field_char {
			v_sprintf_panic(mut pt, p_index, pt.len)
			res.write_string('0x')
			res.write_string(pt[p_index].u64().hex())
			status = .reset_params
			p_index++
			i++
			continue
		}

		if ch == `%` && status == .field_char {
			res.write_b(`%`)
			status = .reset_params
			i++
			continue
		}

		if status == .field_char {
			mut fc_ch1 := `0`
			mut fc_ch2 := `0`
			if (i + 1) < str.len {
				fc_ch1 = str[i + 1]
				if (i + 2) < str.len {
					fc_ch2 = str[i + 2]
				}
			}
			if ch == `+` {
				sign = true
				i++
				continue
			} else if ch == `-` {
				allign = .left
				i++
				continue
			} else if ch in [`0`, ` `] {
				if allign == .right {
					pad_ch = ch
				}
				i++
				continue
			} else if ch == `\'` {
				i++
				continue
			} else if ch == `.` && fc_ch1 >= `1` && fc_ch1 <= `9` {
				status = .check_float
				i++
				continue
			}
			// manage "%.*s" precision field
			else if ch == `.` && fc_ch1 == `*` && fc_ch2 in [`s`, `b`, `q`] {
				v_sprintf_panic(mut pt, p_index, pt.len)
				len := pt[p_index].int()
				p_index++
				v_sprintf_panic(mut pt, p_index, pt.len)
				mut ctrl_c := false
				mut s := match fc_ch2 {
					`s` {
						pt[p_index]
					}
					`b` {
						ss, ctrl_c_ := apply_controls(pt[p_index], true)
						ctrl_c = ctrl_c_
						ss
					}
					`q` {
						apply_posix_escape(pt[p_index])
					}
					else {
						''
					}
				}
				s = if len < s.len { s[..len] } else { s }
				p_index++
				res.write_string(s)
				if ctrl_c {
					return res.str(), p_index, true
				}
				status = .reset_params
				i += 3
				continue
			}
			status = .len_set_start
			continue
		}

		if status == .len_set_start {
			if ch >= `1` && ch <= `9` {
				len0 = int(ch - `0`)
				status = .len_set_in
				i++
				continue
			}
			if ch == `.` {
				status = .check_float
				i++
				continue
			}
			status = .check_type
			continue
		}

		if status == .len_set_in {
			if ch >= `0` && ch <= `9` {
				len0 *= 10
				len0 += int(ch - `0`)
				i++
				continue
			}
			if ch == `.` {
				status = .check_float
				i++
				continue
			}
			status = .check_type
			continue
		}

		if status == .check_float {
			if ch >= `0` && ch <= `9` {
				len1 = int(ch - `0`)
				status = .check_float_in
				i++
				continue
			}
			status = .check_type
			continue
		}

		if status == .check_float_in {
			if ch >= `0` && ch <= `9` {
				len1 *= 10
				len1 += int(ch - `0`)
				i++
				continue
			}
			status = .check_type
			continue
		}

		if status == .check_type {
			if ch == `l` {
				if ch1 == `0` {
					ch1 = `l`
					i++
					continue
				} else {
					ch2 = `l`
					i++
					continue
				}
			} else if ch == `h` {
				if ch1 == `0` {
					ch1 = `h`
					i++
					continue
				} else {
					ch2 = `h`
					i++
					continue
				}
			}
			// signed integer
			else if ch in [`d`, `i`] {
				mut d1 := u64(0)
				mut positive := true

				// println("$ch1 $ch2")
				match ch1 {
					// h for 16 bit int
					// hh fot 8 bit int
					`h` {
						if ch2 == `h` {
							v_sprintf_panic(mut pt, p_index, pt.len)
							x := pt[p_index].i8()
							positive = if x >= 0 { true } else { false }
							d1 = if positive { u64(x) } else { u64(-x) }
						} else {
							x := pt[p_index].i16()
							positive = if x >= 0 { true } else { false }
							d1 = if positive { u64(x) } else { u64(-x) }
						}
					}
					// l  i64
					// ll i64 for now
					`l` {
						// placeholder for future 128bit integer code
						/*
						if ch2 == `l` {
							v_sprintf_panic(p_index, pt.len)
							x := *(&i128(pt[p_index]))
							positive = if x >= 0 { true } else { false }
							d1 = if positive { u128(x) } else { u128(-x) }
						} else {
							v_sprintf_panic(p_index, pt.len)
							x := *(&i64(pt[p_index]))
							positive = if x >= 0 { true } else { false }
							d1 = if positive { u64(x) } else { u64(-x) }
						}
						*/
						v_sprintf_panic(mut pt, p_index, pt.len)
						x := pt[p_index].i64()
						positive = if x >= 0 { true } else { false }
						d1 = if positive { u64(x) } else { u64(-x) }
					}
					// default int
					else {
						v_sprintf_panic(mut pt, p_index, pt.len)
						x := pt[p_index].int()
						positive = if x >= 0 { true } else { false }
						d1 = if positive { u64(x) } else { u64(-x) }
					}
				}
				res.write_string(format_dec_old(d1,
					pad_ch: pad_ch
					len0: len0
					len1: 0
					positive: positive
					sign_flag: sign
					allign: allign
				))
				status = .reset_params
				p_index++
				i++
				ch1 = `0`
				ch2 = `0`
				continue
			}
			// unsigned integer
			else if ch == `u` {
				mut d1 := u64(0)
				positive := true
				v_sprintf_panic(mut pt, p_index, pt.len)
				match ch1 {
					// h for 16 bit unsigned int
					// hh fot 8 bit unsigned int
					`h` {
						if ch2 == `h` {
							d1 = u64(byte(pt[p_index].u16()))
						} else {
							d1 = u64(pt[p_index].u16())
						}
					}
					// l  u64
					// ll u64 for now
					`l` {
						// placeholder for future 128bit integer code
						/*
						if ch2 == `l` {
							d1 = u128(*(&u128(pt[p_index])))
						} else {
							d1 = u64(*(&u64(pt[p_index])))
						}
						*/
						d1 = pt[p_index].u64()
					}
					// default int
					else {
						d1 = u64(pt[p_index].u32())
					}
				}

				res.write_string(format_dec_old(d1,
					pad_ch: pad_ch
					len0: len0
					len1: 0
					positive: positive
					sign_flag: sign
					allign: allign
				))
				status = .reset_params
				p_index++
				i++
				continue
			}
			// hex
			else if ch in [`x`, `X`] {
				v_sprintf_panic(mut pt, p_index, pt.len)
				mut s := ''
				match ch1 {
					// h for 16 bit int
					// hh fot 8 bit int
					`h` {
						if ch2 == `h` {
							x := pt[p_index].i8()
							s = x.hex()
						} else {
							x := pt[p_index].i16()
							s = x.hex()
						}
					}
					// l  i64
					// ll i64 for now
					`l` {
						// placeholder for future 128bit integer code
						/*
						if ch2 == `l` {
							x := *(&i128(pt[p_index]))
							s = x.hex()
						} else {
							x := *(&i64(pt[p_index]))
							s = x.hex()
						}
						*/
						x := pt[p_index].i64()
						s = x.hex()
					}
					else {
						x := pt[p_index].int()
						s = x.hex()
					}
				}

				if ch == `X` {
					s = s.to_upper()
				}

				res.write_string(strconv.format_str(s,
					pad_ch: pad_ch
					len0: len0
					len1: 0
					positive: true
					sign_flag: false
					allign: allign
				))
				status = .reset_params
				p_index++
				i++
				continue
			}

			// float and double
			if ch in [`f`, `F`] {
				v_sprintf_panic(mut pt, p_index, pt.len)
				x := pt[p_index].f64()
				positive := x >= f64(0.0)
				len1 = if len1 >= 0 { len1 } else { def_len1 }
				s := format_fl_old(f64(x),
					pad_ch: pad_ch
					len0: len0
					len1: len1
					positive: positive
					sign_flag: sign
					allign: allign
				)
				res.write_string(if ch == `F` { s.to_upper() } else { s })
				status = .reset_params
				p_index++
				i++
				continue
			} else if ch in [`e`, `E`] {
				v_sprintf_panic(mut pt, p_index, pt.len)
				x := pt[p_index].f64()
				positive := x >= f64(0.0)
				len1 = if len1 >= 0 { len1 } else { def_len1 }
				s := format_es_old(f64(x),
					pad_ch: pad_ch
					len0: len0
					len1: len1
					positive: positive
					sign_flag: sign
					allign: allign
				)
				res.write_string(if ch == `E` { s.to_upper() } else { s })
				status = .reset_params
				p_index++
				i++
				continue
			} else if ch in [`g`, `G`] {
				v_sprintf_panic(mut pt, p_index, pt.len)
				x := pt[p_index].f64()
				positive := x >= f64(0.0)
				mut s := ''
				tx := fabs(x)
				if tx < 999_999.0 && tx >= 0.00001 {
					// println("Here g format_fl [$tx]")
					len1 = if len1 >= 0 { len1 + 1 } else { def_len1 }
					s = format_fl_old(x,
						pad_ch: pad_ch
						len0: len0
						len1: len1
						positive: positive
						sign_flag: sign
						allign: allign
						rm_tail_zero: true
					)
				} else {
					len1 = if len1 >= 0 { len1 + 1 } else { def_len1 }
					s = format_es_old(x,
						pad_ch: pad_ch
						len0: len0
						len1: len1
						positive: positive
						sign_flag: sign
						allign: allign
						rm_tail_zero: true
					)
				}
				res.write_string(if ch == `G` { s.to_upper() } else { s })
				status = .reset_params
				p_index++
				i++
				continue
			}
			// string
			else if ch in [`s`, `b`, `q`] {
				v_sprintf_panic(mut pt, p_index, pt.len)
				mut ctrl_c := false
				s1 := match ch {
					`s` {
						pt[p_index]
					}
					`b` {
						ss, ctrl_c_ := apply_controls(pt[p_index], true)
						ctrl_c = ctrl_c_
						ss
					}
					`q` {
						apply_posix_escape(pt[p_index])
					}
					else {
						''
					}
				}
				pad_ch = ` `
				res.write_string(strconv.format_str(s1,
					pad_ch: pad_ch
					len0: len0
					len1: 0
					positive: true
					sign_flag: false
					allign: allign
				))
				status = .reset_params
				p_index++
				if ctrl_c {
					return res.str(), p_index, true
				}
				i++
				continue
			}
		}

		status = .reset_params
		p_index++
		i++
	}

	return res.str(), p_index, false
}

[inline]
fn v_sprintf_panic(mut pt []string, idx int, len int) {
	if idx >= len {
		pt << ''
		// panic('${idx + 1} % conversion specifiers, but given only $len args')
	}
}

fn fabs(x f64) f64 {
	if x < 0.0 {
		return -x
	}
	return x
}

// strings.Builder version of format_fl
[manualfree]
fn format_fl_old(f f64, p strconv.BF_param) string {
	unsafe {
		mut s := ''
		// mut fs := "1.2343"
		mut fs := strconv.f64_to_str_lnd1(if f >= 0.0 { f } else { -f }, p.len1)
		// println("Dario")
		// println(fs)

		// error!!
		if fs[0] == `[` {
			s.free()
			return fs
		}

		if p.rm_tail_zero {
			tmp := fs
			fs = remove_tail_zeros_old(fs)
			tmp.free()
		}
		mut res := strings.new_builder(if p.len0 > fs.len { p.len0 } else { fs.len })

		mut sign_len_diff := 0
		if p.pad_ch == `0` {
			if p.positive {
				if p.sign_flag {
					res.write_b(`+`)
					sign_len_diff = -1
				}
			} else {
				res.write_b(`-`)
				sign_len_diff = -1
			}
			tmp := s
			s = fs.clone()
			tmp.free()
		} else {
			if p.positive {
				if p.sign_flag {
					tmp := s
					s = '+' + fs
					tmp.free()
				} else {
					tmp := s
					s = fs.clone()
					tmp.free()
				}
			} else {
				tmp := s
				s = '-' + fs
				tmp.free()
			}
		}

		dif := p.len0 - s.len + sign_len_diff

		if p.allign == .right {
			for i1 := 0; i1 < dif; i1++ {
				res.write_b(p.pad_ch)
			}
		}
		res.write_string(s)
		if p.allign == .left {
			for i1 := 0; i1 < dif; i1++ {
				res.write_b(p.pad_ch)
			}
		}

		s.free()
		fs.free()
		tmp_res := res.str()
		res.free()
		return tmp_res
	}
}

[manualfree]
fn format_es_old(f f64, p strconv.BF_param) string {
	unsafe {
		mut s := ''
		mut fs := strconv.f64_to_str_pad(if f > 0 { f } else { -f }, p.len1)
		if p.rm_tail_zero {
			fs = remove_tail_zeros_old(fs)
		}
		mut res := strings.new_builder(if p.len0 > fs.len { p.len0 } else { fs.len })

		mut sign_len_diff := 0
		if p.pad_ch == `0` {
			if p.positive {
				if p.sign_flag {
					res.write_b(`+`)
					sign_len_diff = -1
				}
			} else {
				res.write_b(`-`)
				sign_len_diff = -1
			}
			tmp := s
			s = fs.clone()
			tmp.free()
		} else {
			if p.positive {
				if p.sign_flag {
					tmp := s
					s = '+' + fs
					tmp.free()
				} else {
					tmp := s
					s = fs.clone()
					tmp.free()
				}
			} else {
				tmp := s
				s = '-' + fs
				tmp.free()
			}
		}

		dif := p.len0 - s.len + sign_len_diff
		if p.allign == .right {
			for i1 := 0; i1 < dif; i1++ {
				res.write_b(p.pad_ch)
			}
		}
		res.write_string(s)
		if p.allign == .left {
			for i1 := 0; i1 < dif; i1++ {
				res.write_b(p.pad_ch)
			}
		}
		s.free()
		fs.free()
		tmp_res := res.str()
		res.free()
		return tmp_res
	}
}

fn remove_tail_zeros_old(s string) string {
	mut i := 0
	mut last_zero_start := -1
	mut dot_pos := -1
	mut in_decimal := false
	mut prev_ch := byte(0)
	for i < s.len {
		ch := unsafe { s.str[i] }
		if ch == `.` {
			in_decimal = true
			dot_pos = i
		} else if in_decimal {
			if ch == `0` && prev_ch != `0` {
				last_zero_start = i
			} else if ch >= `1` && ch <= `9` {
				last_zero_start = -1
			} else if ch == `e` {
				break
			}
		}
		prev_ch = ch
		i++
	}

	mut tmp := ''
	if last_zero_start > 0 {
		if last_zero_start == dot_pos + 1 {
			tmp = s[..dot_pos] + s[i..]
		} else {
			tmp = s[..last_zero_start] + s[i..]
		}
	} else {
		tmp = s
	}
	if unsafe { tmp.str[tmp.len - 1] } == `.` {
		return tmp[..tmp.len - 1]
	}
	return tmp
}

// max int64 9223372036854775807
fn format_dec_old(d u64, p strconv.BF_param) string {
	mut s := ''
	mut res := strings.new_builder(20)
	mut sign_len_diff := 0
	if p.pad_ch == `0` {
		if p.positive {
			if p.sign_flag {
				res.write_b(`+`)
				sign_len_diff = -1
			}
		} else {
			res.write_b(`-`)
			sign_len_diff = -1
		}
		s = d.str()
	} else {
		if p.positive {
			if p.sign_flag {
				s = '+' + d.str()
			} else {
				s = d.str()
			}
		} else {
			s = '-' + d.str()
		}
	}
	dif := p.len0 - s.len + sign_len_diff

	if p.allign == .right {
		for i1 := 0; i1 < dif; i1++ {
			res.write_b(p.pad_ch)
		}
	}
	res.write_string(s)
	if p.allign == .left {
		for i1 := 0; i1 < dif; i1++ {
			res.write_b(p.pad_ch)
		}
	}
	return res.str()
}
