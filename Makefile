all: pyperler

pyperler: pyperler.pyx perl.pxd setup.py
	python setup.py build
	ln -sf `find build -name pyperler.so`
interpret:
	gcc interpret.c -o interpret `perl -MExtUtils::Embed -e ccopts -e ldopts`

check: pyperler
	python test.py

clean:
	rm -rf build pyperler.c
