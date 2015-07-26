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
    >>> print( t.table() )
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
arrays.

The obvious complications for bridging the differences between Python and Perl are

 1. Weak typing; there's no difference between 1 and "1" in Perl
 2. Void context vs. scalar context vs. list context

For choosing a strategy to deal with this, we follow the Philosophy of Python:

    Explicit is better than implicit.
    (...)
    In the face of ambiguity, refuse the temptation to guess.

Weak typing
-----------
Whenever we return a scalar value from Perl, this remains boxed as an object of
type pyperler.ScalarValue.  This can either be explicitly cast to str, int, or
double, or that can happen implicitly through type inference in binary
operations. We 'refuse the tempation to guess' when applying a binary operator
to a pyperler.ScalarValue: this raises a TypeError.

In case the scalar value is a hashref resp. an arrayref, it supports all the
operations that Python's built-in dict object resp. list object support.

In case the scalar value is a blessed reference, it additionally supports
methods calls. When there's a naming clash between the Python built-in method
and the blessed reference's methods, the Python ones take precedence. The "hidden"
methods are still available through a indexable attribute 'F', like

    >>> arrayref = i('package a; sub append { print $_[1] }; bless "a", []')
    >>> arrayref.F['append'](23)
    23

Void context vs. scalar context vs. list context
------------------------------------------------
Any pyperler object that represents a Perl callable has methods `void_context`,
`list_context`, and `scalar_context`. In addition, `__call__` (ie the function
call operator) is a shorthand for `scalar_context`.

Similarly, the Interpreter object has methods `void_context`, `list_context`,
and `scalar_context`. They take a single string as an argument, which is evaluated
as Perl code. `__call__` is a shorthand for `scalar_context`, and also `__getitem__`
is a shorthand for `list_context`. (This last  thing wouldn't be useful for
callables, because the case of zero arguments is a syntax error in Python.)

`void_context` returns None
`scalar_context` returns a pyperler.ScalarValue
`list_context` returns a pyperler.ListValue. This is just a python tuple of pyperler.ScalarValue objects, with a few convenience methods for casting all of them.

License
-------
PyPerler is Copyright (C) 2013-2015, Timo Kluck. It is distributed under the
General Public License, version 3 or later.

The file PythonObject.pm contains code from from PyPerl, which is Copyright
2000-2001 ActiveState. This code can be distributed under the same terms as
Perl, which includes distribution under the GPL version 1 or later.

For your convenience, the General Public License version 3 is included as the
file COPYING.
