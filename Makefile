all: pyperler

PYTHON ?= python3

pyperler: pyperler.pyx perl.pxd setup.py
	$(PYTHON) setup.py build

env:
	virtualenv -p $(PYTHON) env

check: pyperler env
	env/bin/python setup.py install
	(cd env && PERL5LIB="../perllib" bin/python ../test.py)

clean:
	rm -rf build pyperler.c env

install: pyperler
	$(PYTHON) setup.py install
