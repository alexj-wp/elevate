.PHONY: test cover tags clean release

GIT ?= /usr/local/cpanel/3rdparty/bin/git
RELEASE_TAG ?= release

test:
	perl -cw elevate-cpanel
	/usr/local/cpanel/3rdparty/bin/prove t/00_load.t
	/usr/local/cpanel/3rdparty/bin/yath test -j8 t/*.t

cover:
	/usr/bin/rm -rf cover_db
	HARNESS_PERL_SWITCHES="-MDevel::Cover=-loose_perms,on,-coverage,statement,branch,condition,subroutine,-ignore,.,-select,elevate-cpanel" prove -j8 t/*.t ||:
	cover -silent
	find cover_db -type f -exec chmod 644 {} \;
	find cover_db -type d -exec chmod 755 {} \;

tags:
	/usr/bin/ctags -R --languages=perl elevate-cpanel t

clean:
	rm -f tags

release: version := $(shell dc -f version -e '1 + p')
release:
	echo ${version} > version
	sed -i -re "/^#<<V/,+1 s/VERSION => [0-9]*;/VERSION => ${version};/" elevate-cpanel
	$(GIT) commit -m "Release version ${version}" -- version elevate-cpanel
	$(GIT) tag -f $(RELEASE_TAG)
	$(GIT) push origin
	$(GIT) push --force origin tag $(RELEASE_TAG)
