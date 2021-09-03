.PHONY: all prod fmt test testfmt

all:
	@v run build.vsh

prod:
	@v run build.vsh -prod

fmt:
	v fmt -w .

test:
	LANG=C v test .	

testfmt:
	v fmt -verify .
