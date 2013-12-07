all: pyperler

PYTHON ?= python

pyperler: pyperler.pyx perl.pxd setup.py
	$(PYTHON) setup.py build

check: pyperler
	ln -sf `find build -name pyperler.so`
	$(PYTHON) test.py

check3: pyperler
	ln -sf "`find build -name pyperler.cpython*.so`" -n pyperler.so
	$(PYTHON) test.py

clean:
	rm -rf build pyperler.c
