default:
	make doc
	make post
	make clean

doc:
	pdflatex doc
	pdflatex doc

clean:
	rm -f doc.log
	rm -f doc.aux
	rm -f *~ a.a

post:
	cp doc.pdf ~/Lightandmatter/spotter/doc.pdf
