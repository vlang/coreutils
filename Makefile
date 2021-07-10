.PHONY: all fmt test testfmt

all:
	@v run build.vsh

fmt:
	v fmt -w .

test:
	v test .	

testfmt:
	v fmt -verify .
