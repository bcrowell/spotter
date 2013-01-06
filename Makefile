VERSION = 3.0.0

CGI_GENERAL = /usr/lib/cgi-bin
WEB_SERVER_GROUP = www-data
WEB_SERVER_DATA = /var/www
CGI = $(CGI_GENERAL)/spotter3
   # ... can coexist on the same server with an installation of spotter 2.x
ANSWERS = $(CGI)/answers
DATA = $(CGI)/data
JS = $(WEB_SERVER_DATA)/spotter_js/$(VERSION)

NEW_TINT = /home/bcrowell/Documents/programming/tint/tint
   # ... on my own system, this is the newest version; always update to this version

doc:
	pdflatex doc
	pdflatex doc

s:
	touch strings/* tint
	make Tint.pm

Tint.pm: strings/* tint
	perl -e 'if (-e "$(NEW_TINT)") {system("cp $(NEW_TINT) .")}'
	chmod +x tint
	./tint --generate="perl" strings/* >Tint.pm

install: Tint.pm
	perl -e 'if (-e "$(NEW_TINT)") {system("cp $(NEW_TINT) .")}'
	install -d $(JS)
	install -d $(CGI)
	install -d $(ANSWERS)
	install --mode=775 -d $(DATA)
	chgrp $(WEB_SERVER_GROUP) $(DATA)
	install *.cgi *.pm config.json $(CGI)
	install --mode=644 sample.xml $(ANSWERS)
	install *.js $(JS)	

depend:
	# The following is for debian, ubuntu, etc.:
	apt-get install libxml-parser-perl libxml-simple-perl libdigest-sha-perl libjson-perl libmail-sendmail-perl

clean:
	rm -f doc.log
	rm -f doc.aux
	rm -f *~ a.a
	# ... done.

test:
	cd tests ;\
	../Calc.pl -pc -i testsuite -o testsuite.out && \
	cat testsuite.out ;\
	perl -I.. ./test_sig_figs.pl

post:
	cp doc.pdf $(HOME)/Lightandmatter/spotter/
