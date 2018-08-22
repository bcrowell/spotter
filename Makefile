VERSION = 3.0.5
# ... when changing this, also change WebInterface.pm and InstructorInterface.pm

CGI_GENERAL = /usr/lib/cgi-bin
WEB_SERVER_GROUP = www-data
WEB_SERVER_DATA = /var/www
   # ... was /var/www on debian until ca. 2014, then changed to /var/www/html
CGI = $(CGI_GENERAL)/spotter3
   # ... can coexist on the same server with an installation of spotter 2.x
ANSWERS = $(CGI)/answers
DATA = $(CGI)/data
JS = $(WEB_SERVER_DATA)/spotter_js/$(VERSION)

NEW_TINT = /home/bcrowell/Documents/programming/tint/tint
   # ... on my own system, this is the newest version; always update to this version

s:
	touch strings/* tint
	make Tint.pm

Tint.pm: strings/* tint
	perl -e 'if (-e "$(NEW_TINT)") {system("cp $(NEW_TINT) .")}'
	chmod +x tint
	./tint --generate="perl" strings/* >Tint.pm

install: Tint.pm
	@rgrep DocumentRoot /etc/apache2/ | awk '{print $$NF}' | head -n 1 >dr.temp
	@perl -e '$$dr = `cat dr.temp`; chomp $$dr; if ($$dr ne "$(WEB_SERVER_DATA)") {print "warning: WEB_SERVER_DATA = $(WEB_SERVER_DATA) in Makefile, but it should probably be $$dr"}'
	@# ... http://serverfault.com/questions/611696/detecting-in-a-script-whether-apache2-root-is-var-www-or-var-www-html
	perl -e 'if (!-d "$(WEB_SERVER_DATA)") {print "error: WEB_SERVER_DATA = $(WEB_SERVER_DATA) in Makefile, but that directory does not exist; edit the Makefile and set this correctly for your server, e.g., to /var/www"; exit(-1)}'
	perl -e 'if (-e "$(NEW_TINT)") {system("cp $(NEW_TINT) .")}'
	install -d $(CGI)
	install -d $(ANSWERS)
	install --mode=775 -d $(DATA)
	chgrp $(WEB_SERVER_GROUP) $(DATA)
	install *.cgi *.pm config.json $(CGI)
	install --mode=644 sample.xml $(ANSWERS)
	# in the following, on ubuntu systems from after ca. 2014, we need /var/www/html rather than /var/www;
        #         can work around with a symbolic link: ln -s /var/www/spotter_js /var/www/html/spotter_js
	install -d $(JS)
	install *.js $(JS)

depend:
	# The following is for debian, ubuntu, etc.:
	apt-get install libxml-parser-perl libxml-simple-perl libdigest-sha-perl libjson-perl libmail-sendmail-perl libcgi-application-plugin-authentication-perl libcgi-session-perl libcarp-always-perl

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
	@echo "Generating diff of old and new test-suite outputs (not including sig figs):"
	@diff tests/testsuite.out tests/testsuite.out.save
	@echo "...end of diff"

post:
	cp doc/doc.pdf $(HOME)/Lightandmatter/spotter/
