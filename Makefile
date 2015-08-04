all: pyperler

PYTHON ?= python

pyperler: pyperler.pyx perl.pxd setup.py
	$(PYTHON) setup.py build

check: pyperler
	$(PYTHON) setup.py install --install-lib="`pwd`/lib"
	PYTHONPATH="`pwd`/lib" $(PYTHON) test.py

clean:
	rm -rf build pyperler.c lib
