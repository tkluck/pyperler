all: pyperler

pyperler: pyperler.pyx perl.pxd setup.py
	LDFLAGS=`perl -MExtUtils::Embed -e ldopts` CFLAGS=`perl -MExtUtils::Embed -e ccopts` python setup.py build
	ln -sf `find build -name pyperler.so`
interpret:
	gcc interpret.c -o interpret `perl -MExtUtils::Embed -e ccopts -e ldopts`

check: pyperler
	python test.py
