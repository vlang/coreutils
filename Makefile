.PHONY: all prod fmt test testfmt clean

all:
	@v run build.vsh

prod:
	@v run build.vsh -prod

fmt:
	v fmt -w .

test:
	LANG=C v -Wimpure-v -W test .

testfmt:
	v fmt -verify .

clean:
	$(RM) -r bin
