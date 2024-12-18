module main

fn test_numbers_embdded_in_text() {
	a := 'log10.txt'
	b := 'log9.txt'

	assert compare_strings(&b, &a) > 0
	assert natural_compare(&b, &a) < 0

	assert compare_strings(&a, &b) < 0
	assert natural_compare(&a, &b) > 0

	assert compare_strings(&a, &a) == 0
	assert natural_compare(&a, &a) == 0

	assert compare_strings(&b, &b) == 0
	assert natural_compare(&b, &b) == 0
}

fn test_numbers_two_embdded_in_text() {
	a := '0log10.txt'
	b := '1log9.txt'

	assert compare_strings(&a, &b) < 0
	assert natural_compare(&a, &b) < 0

	assert compare_strings(&b, &a) > 0
	assert natural_compare(&b, &a) > 0

	assert compare_strings(&a, &a) == 0
	assert natural_compare(&a, &a) == 0

	assert compare_strings(&b, &b) == 0
	assert natural_compare(&b, &b) == 0
}

fn test_no_numbers_in_text() {
	a := 'abc'
	b := 'bca'

	assert compare_strings(&a, &b) < 0
	assert natural_compare(&a, &b) < 0

	assert compare_strings(&b, &a) > 0
	assert natural_compare(&b, &a) > 0

	assert compare_strings(&a, &a) == 0
	assert natural_compare(&a, &a) == 0

	assert compare_strings(&b, &b) == 0
	assert natural_compare(&b, &b) == 0
}
