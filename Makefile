.PHONY: all prod fmt test testfmt clean

# Make doesn't have a built-in and reliable way to get the number of jobs...
JOBS ?= 1

all:
	@v run build.vsh --cpus=$(JOBS)

prod:
	@v run build.vsh -prod --cpus=$(JOBS)

fmt:
	v fmt -w .

test:
	LANG=C v -Wimpure-v -W test .

testfmt:
	v fmt -verify .

clean:
	$(RM) -r bin
