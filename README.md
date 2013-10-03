PyPerler
========

Quick install
-------------

You'll need cython, perl and the perl headers. On Ubuntu, the first two are just

    $ sudo apt-get install cython perl-base

but I don't know how to get the files in /usr/lib/perl/5.14/CORE/, maybe CPAN?

Then compilation and installation is 

    $ python setup.py build && sudo python setup.py install

Introduction
------------
PyPerler allows you to seemlessly interact with Perl code from Python. Python
dicts and Perl hashes map into eachother transparently, and so do lists and
arrays. Perl functions and methods are called either in scalar or list context
depending on how you use them in Python. For example:

    >>> import pyperler
    >>> i = pyperler.Interpreter()
    >>> i('@array = qw / a b c /;')

will allow you to access `@array` in list context by doing:

    >>> for i in i['@array']: print i
    a
    b
    c

or in scalar context, returning its length, by doing:

    >>> for i in range(i['@array']): print i
    0
    1
    2

Actually, you can also use `i.Aarray` to access the array. This is actually the
preferred way, as it also supports setting:

    >>> i.Aarray[1] = 'd'
    >>> list(i.Aarray)
    ['a', 'd', 'c']

There is support for hashes and objects (blessed references), too. See the
doctests for more examples.

Support for direct function calling is planned, as is passing Python functions
as callbacks to Perl.

License
-------
PyPerler is released under the General Public License, version 3 or later.
Refer to the file COPYING for the licensing conditions.



Copyright (C) 2013, Timo Kluck
