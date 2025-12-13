module main

fn test_ignore() {
	args := new_args(['t', '-i'])!
	assert args.ignore == true
}

fn test_unset() {
	args := new_args(['t', '-i', '-u', 'ABC'])!
	assert 'ABC' in args.unsets

	multi_args := new_args(['t', '-i', '-u', 'ABC', '-u', 'EFG'])!
	assert 'ABC' in multi_args.unsets
	assert 'EFG' in multi_args.unsets
}
