doc:
	pdflatex doc
	pdflatex doc

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
