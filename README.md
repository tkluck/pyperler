PyPerler
========

Quick introduction
------------------
PyPerler gives you the power of CPAN, and your (legacy?) perl packages, in
Python.  Using Perl stuff is as easy as:

    >>> import pyperler; i = pyperler.Interpreter()
    >>> # use a CPAN module
    >>> Table = i.use('Text::Table')
    >>> t = Table("Planet", "Radius\nkm", "Density\ng/cm^3")
    >>> _ = t.load(
    ...    [ "Mercury", 2360, 3.7 ],
    ...    [ "Venus", 6110, 5.1 ],
    ...    [ "Earth", 6378, 5.52 ],
    ...    [ "Jupiter", 71030, 1.3 ],
    ... )
    >>> for line in t.table(): print line
    Planet  Radius Density
            km     g/cm^3 
    Mercury  2360  3.7    
    Venus    6110  5.1    
    Earth    6378  5.52   
    Jupiter 71030  1.3    

If you install the `Class::Inspector` CPAN package, then PyPerler will even get
you introspection for use in IPython.

Quick install
-------------

You'll need cython, perl and the perl headers. On Ubuntu, these are just

    $ sudo apt-get install cython perl-base perl

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

License
-------
PyPerler is Copyright (C) 2013, Timo Kluck. It is distributed under the General
Public License, version 3 or later.

The file PythonObject.pm contains code from from PyPerl, which is Copyright
2000-2001 ActiveState. This code can be distributed under the same terms as
Perl, which includes distribution under the GPL version 1 or later.

For your convenience, the General Public License version 3 is included as the
file COPYING.
