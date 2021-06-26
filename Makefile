.PHONY: all fmt testfmt

all:
	@v run build.vsh

fmt:
	v fmt -w .

# TODO: add tests
test: testfmt

testfmt:
	v fmt -verify .
