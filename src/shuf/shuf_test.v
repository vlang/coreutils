import os
import common.testing

const eol = testing.output_eol()

const shuf = testing.prepare_executable('shuf')

const test_txt_path = os.join_path(testing.temp_folder, 'test.txt')

fn test_echo() {
	res := os.execute('${shuf} -e aa bb')
	assert res.output == 'aa${eol}bb${eol}' || res.output == 'bb${eol}aa${eol}'
}

fn test_file() {
	os.write_file(test_txt_path, 'hello\nworld!')!
	res := os.execute('${shuf} ${test_txt_path}')
	assert res.output == 'hello${eol}world!${eol}' || res.output == 'world!${eol}hello${eol}'
}

fn test_zero_terminated_echo() {
	res := os.execute('${shuf} -z -e aa bb')
	assert res.output == 'aabb' || res.output == 'bbaa'
}

fn test_zero_terminated_file() {
	os.write_file(test_txt_path, 'hello\nworld!')!
	res := os.execute('${shuf} -z ${test_txt_path}')
	assert res.output == 'hello${eol}world!'
}

fn test_head_count() {
	res := os.execute('${shuf} -n 5 -i 1-10')
	println(res.output.split_into_lines())
	assert res.output.split_into_lines().len == 5
}

fn test_input_range() {
	res := os.execute('${shuf} -i 1-10')
	assert res.output.split_into_lines().len == 10
}

fn test_random_source() {
	os.write_file(test_txt_path, 'hello\nworld!')!
	res := os.execute('${shuf} -i 1-5 --random-source ${test_txt_path}')
	assert res.output == '1${eol}4${eol}5${eol}2${eol}3${eol}'
}

fn test_unknown_option() ? {
	res := os.execute('${shuf} -x')
	assert res.exit_code == 1
}
