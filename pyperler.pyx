# vim: set fileencoding=utf-8 :
#
# pyperler.pyx
#
# Copyright (C) 2013-2015, Timo Kluck <tkluck@infty.nl>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

r"""
>>> import pyperler
>>> i = pyperler.Interpreter()

Accessing scalar variables:
>>> i("$a = 2 + 2;")
4
>>> i.Sa
4
>>> i('$a')
4
>>> list(range(i.Sa))
[0, 1, 2, 3]
>>> i.Sa = 5
>>> list(range(i.Sa))
[0, 1, 2, 3, 4]
>>> i('undef')
<pyperler.undef>

Integer, float, and string conversions:
>>> i.Sb = 2.3
>>> i.Sb
2.3
>>> i.Sc = "abc"
>>> i.Sc
'abc'

Evaluating list expressions in array context:
>>> i["qw / a b c d e /"].strings()
('a', 'b', 'c', 'd', 'e')

With perl's weak typing, any non-number string has the integer value 0:
>>> i["qw / a b c d e /"].ints()
(0, 0, 0, 0, 0)

If we do not cast, we get a list of pyperler.ScalarValue objects. Their
`repr` is their string value:
>>> list(i["qw / a b c d e /"])
['a', 'b', 'c', 'd', 'e']

In scalar context, an array yields its length:
>>> i("@array = qw / a b c d e /")
5
>>> i("@array")
5

which is also available from Python:
>>> len(i.Aarray)
5

Fun with Perl's secret operators:
>>> i("()= qw / a b c d e /")
5

Accessing array values:
>>> i("@d = (10 .. 20)")
11
>>> i.Ad.ints()
(10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20)
>>> i.Ad[2]
12
>>> list(i.Ad)[2]
12
>>> i.Ad[0] = 9
>>> int(i('$d[0]'))
9
>>> i['@d[0..2]'].ints()
(9, 11, 12)
>>> i.Ad.ints()
(9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20)

Assigning iterables to arrays:
>>> i.Ad = (10 for _ in range(5))
>>> i.Ad.ints()
(10, 10, 10, 10, 10)
>>> i.Aletters = "nohtyP ni lreP"
>>> i('@letters = reverse @letters')
14
>>> list(i.Aletters)
['P', 'e', 'r', 'l', ' ', 'i', 'n', ' ', 'P', 'y', 't', 'h', 'o', 'n']

Accessing hash values:
>>> i("%b = (greece => 'Aristotle', germany => 'Hegel');")
4
>>> i.Pb['greece']
'Aristotle'
>>> i.Pb['germany'] = 'Kant'
>>> i('$c = $b{germany}')
'Kant'
>>> i.Sc
'Kant'
>>> i.Pparrot = {'dead': True}
>>> i("$parrot{dead}")
1

Accessing objects (we assign to _ to discard the meaningless return values):
>>> _ = i("unshift @INC, './perllib'")
>>> i.void_context("use Car; $car = Car->new")
>>> i.Scar.set_brand("Toyota")
<pyperler.undef>
>>> i.Scar.drive(20)
<pyperler.undef>
>>> i("$car->distance")
20
>>> i.Scar.distance()
20
>>> i.Scar.drive(20)
<pyperler.undef>

Verify that this makes the intended change to the object:
>>> i("$car->distance")
40
>>> i.Scar.distance()
40

Catching perl exceptions ('die'):
>>> i.Scar.out_of_gas() # doctest: +ELLIPSIS
Traceback (most recent call last):
...
RuntimeError: Out of gas! at perllib/Car.pm line ...
<BLANKLINE>

Nested structures:
>>> _ = i("$a = { dictionary => { a => 65, b => 66 }, array => [ 4, 5, 6] }")
>>> i.Sa['dictionary']['a']
65
>>> i.Sa['array'][1]
5

Assigning non-string iterables to a nested element will create an arrayref:
>>> i.Sa['array'] = range(2,5)
>>> i["@{ $a->{array} }"].ints()
(2, 3, 4)

Similarly, assiging a dict to a nested element will create a hashref:
>>> i.Sa['dictionary'] = {'c': 67, 'd': 68}
>>> int(i('$a->{dictionary}->{c}'))
67
>>> sorted(i['keys %{ $a->{dictionary} } '].strings())
['c', 'd']

Calling subs:
>>> i("sub do_something { for (1..10) { 2 + 2 }; return 3; }")
<pyperler.undef>
>>> i.Fdo_something()
3
>>> i("sub add_two { return $_[0] + 2; }")
<pyperler.undef>
>>> i.Fadd_two("4")
6

Anonymous subs:
>>> i('sub { return 2*$_[0]; }')(6)
12

In packages:
>>> i.F['Car::all_brands'].list_context()
('Toyota', 'Nissan')

Passing a Perl function as a callback to python. You'll need to
specify whether you want it to evaluate in scalar context or
list context:
>>> def long_computation(on_ready):
...     for i in range(10**5): 2 + 2
...     return on_ready(5)
...
>>> long_computation(i('sub { return 4; }').scalar_context)
4
>>> i('sub callback { return $_[0]; }')
<pyperler.undef>
>>> long_computation(i.Fcallback.scalar_context)
5

You can maintain a reference to a Perl object, without it being
a Perl variable:
>>> car = i('Car->new')
>>> car.set_brand('Chevrolet')
<pyperler.undef>
>>> car.drive(20)
<pyperler.undef>
>>> car.brand()
'Chevrolet'
>>> del car   # this deletes it on the Perl side, too

>>> i('sub p { return $_[0] ** $_[1]; }');
<pyperler.undef>
>>> i.Fp(2,3)
8.0

But the canonical way is this:
>>> Car = i.use('Car')
>>> car = Car()
>>> car.drive(20)
<pyperler.undef>
>>> car.set_brand('Honda');
<pyperler.undef>
>>> car.brand()
'Honda'

You can access class methods by calling them on the class:
>>> Car.all_brands.list_context()
('Toyota', 'Nissan')

You can also pass Python functions as Perl callbacks:
>>> def f(): return 3
>>> i('sub callit { return $_[0]->() }');
<pyperler.undef>
>>> i.Fcallit(f)
3
>>> def g(x): return x**2
>>> i('sub pass_three { return $_[0]->(3) }');
<pyperler.undef>
>>> i.Fpass_three(g)
9
>>> i('sub call_first { return $_[0]->($_[1]); }');
<pyperler.undef>
>>> i.Fcall_first(lambda x: eval(str(x)), "2+2")
4

And this even works if you switch between Perl and Python several times:
>>> i.Fcall_first(i, "2+2") # no lock or segfault
4

And also when we don't discard the return value:
>>> def h(x): return int(i(x))
>>> i.Fcall_first(h, "2+2")
4

Test that we recover objects when we pass them through perl
>>> class FooBar(object):
...    def __init__(self):
...       self._last_set_item = None
...    def foo(self):
...       return "bar"
...    def __getitem__(self, key):
...         return 'key length: %d' % len(key)
...    def __setitem__(self, key, value):
...         self._last_set_item = value
...    def __len__(self):
...         return 31337
...    def __bool__(self):
...         return bool(self._last_set_item)
...
>>> i('sub shifter { shift; }')
<pyperler.undef>
>>> foobar = FooBar()
>>> type(foobar)
<class 'pyperler.FooBar'>
>>> type(i.Fshifter(FooBar()))
<class 'pyperler.FooBar'>

And that indexing and getting the length works:
>>> i('sub { return $_[0]->{miss}; }')(foobar)
'key length: 4'
>>> i('sub { $_[0]->{funny_joke} = "dkfjasd"; return undef; }')(foobar)
<pyperler.undef>
>>> i('sub { return $_[0] ? "YES" : "no"; }')(foobar)
'YES'
>>> i('sub { return scalar@{ $_[0] }; }')(foobar)
31337

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
<BLANKLINE>

Using list context:
>>> a,b,c = i['qw / alpha beta gamma /']
>>> b
'beta'

Test using more than 32-bits numbers:
>>> i('sub { shift; }')(2**38)
274877906944

Test using negative numbers:
>>> i('sub { shift; }')(-1)
-1

Test passing blessed scalar values through Python:
>>> i.Sdaewoo_matiz = Car()
>>> i('ref $daewoo_matiz')
'Car'

We even support introspection if your local CPAN installation sports Class::Inspector:
>>> Inspector = i.use('Class::Inspector') # this line is not needed, but if it fails you know you need to install Class::Inspector
>>> Car.__dir__()
['all_brands', 'brand', 'distance', 'drive', 'new', 'out_of_gas', 'set_brand']
>>> nissan_sunny = Car()
>>> nissan_sunny.__dir__()
['all_brands', 'brand', 'distance', 'drive', 'new', 'out_of_gas', 'set_brand']

Fail gracefully when a variable doesn't exist:
>>> i.Snon_existing_variable
Traceback (most recent call last):
...
NameError: name '$non_existing_variable' is not defined

Use Perl's awesome interface to regular expressions for shorter code:
>>> i.S_ = "abc"
>>> a,b,c = i['/(.)(.)(.)/']
>>> a,b,c
('a', 'b', 'c')

We support the common perl idiom
while(my $row = $object->next) {
    ...
}
for iteration:

>>> i('use DummyIterable')
<pyperler.undef>
>>> i.void_context('$numbers = bless [1,2,3], "DummyIterable"')
>>> for a in i.Snumbers:
...     print(a)
...
1
2
3

Also nice for string quoting:
>>> a,b,c = i['qw/a b c/']
>>> a
'a'

Also, creating a new interpreter works like you'd expect:
>>> i.Sa = 3
>>> i.Sa
3
>>> i = pyperler.Interpreter()
>>> i.Sa
Traceback (most recent call last):
...
NameError: name '$a' is not defined

Deal with null-bytes in perl strings:
>>> a = bytes(i('"a\\x00b"'))
>>> len(a)
3

Check that we have all python's array methods on an arrayref:
>>> a = i("[1,2,3,4,5,6]")
>>> a.append(7)
>>> a
[1, 2, 3, 4, 5, 6, 7]
>>> b = a.copy()
>>> b.append(7)
>>> a,b
([1, 2, 3, 4, 5, 6, 7], [1, 2, 3, 4, 5, 6, 7, 7])
>>> a.count(7), b.count(7)
(1, 2)
>>> a.clear(); a
[]
>>> a= i("[1,2,3,4,5,6,7]")
>>> a.extend((x**3 for x in range(2,4))); a
[1, 2, 3, 4, 5, 6, 7, 8, 27]
>>> a.index(27)
8
>>> a.insert(8,9); a
[1, 2, 3, 4, 5, 6, 7, 8, 9, 27]
>>> a.pop(), a
(27, [1, 2, 3, 4, 5, 6, 7, 8, 9])
>>> a.pop(2), a
(3, [1, 2, 4, 5, 6, 7, 8, 9])
>>> a.remove(2); a
[1, 4, 5, 6, 7, 8, 9]
>>> a.reverse(); a
[9, 8, 7, 6, 5, 4, 1]

We cannot directly compare scalar values, because we don't
know whether you want string or number comparison. You can
make that explicit by specifying a key:
>>> a.append(10)
>>> a.sort(key=int); a
[1, 4, 5, 6, 7, 8, 9, 10]
>>> a.sort(key=str); a
['1', '10', '4', '5', '6', '7', '8', '9']

"""
from libc.stdlib cimport malloc, free
cimport dlfcn
from cpython cimport PyObject, Py_XINCREF, PY_MAJOR_VERSION
cimport perl

from collections import defaultdict

include "PythonObjectPm.pyx"

cpdef PERL_SYS_INIT3(argv, env):
    cdef int argc
    cdef char** cargv
    cdef char** cenv
    perl.PERL_SYS_INIT3(&argc, &cargv, &cenv)

include "callbacks.pyx"

cdef void xs_init():
    cdef char *file = "file"

    perl.newXS("DynaLoader::boot_DynaLoader", &perl.boot_DynaLoader, file);
    perl.newXS("Python::bootstrap", &dummy, file)
    perl.newXS("Python::Object::bootstrap", &dummy, file)

    perl.newXS("Python::PyObject_CallObject", <void*>&call_object, file)
    perl.newXS("Python::PyObject_Str", &object_to_str, file)
    perl.newXS("Python::PyObject_IsTrue", &object_to_bool, file)
    perl.newXS("Python::PyObject_GetItem", &object_get_item, file)
    perl.newXS("Python::PyObject_SetItem", &object_set_item, file)
    perl.newXS("Python::PyObject_Length", &object_length, file)
    perl.newXS("Python::PyMapping_Check", &object_is_mapping, file)
    perl.newXS("Python::PyObject_DelItem", &object_del_item, file)

cdef class _PerlInterpreter:
    cdef perl.PerlInterpreter *_this
    def __cinit__(self):
        perl.my_perl = perl.perl_alloc() 
        if perl.my_perl is NULL:
            raise MemoryError()
        perl.perl_construct(perl.my_perl)
        perl.PL_exit_flags |= perl.PERL_EXIT_DESTRUCT_END;
    def parse(self, argv):
        cdef char **string_buf = <char**>malloc(len(argv) * sizeof(char*))
        for i in range(len(argv)):
            string_buf[i] = <char*>(argv[i])
        perl.perl_parse(perl.my_perl, &xs_init, len(argv), string_buf, NULL)
        free(string_buf)

    def run(self):
        perl.perl_run(perl.my_perl)

cdef perl.SV* _expression_sv(object expression):
    if isinstance(expression, ScalarValue):
        return perl.SvREFCNT_inc((<ScalarValue>expression)._sv)
    else:
        expression = str(expression).encode()
        return perl.newSVpvn_utf8(expression, len(expression), True)

cdef class Interpreter(object):
    cdef _PerlInterpreter _interpreter
    cdef object _iterable_methods
    cdef readonly ScalarValue _ref
    cdef readonly ScalarValue _is_numeric
    cdef readonly ScalarValue _is_integer
    def __init__(self):
        self._interpreter = _PerlInterpreter()
        self._interpreter.parse([b"",b"-e",PythonObjectPackage])
        self._interpreter.run()
        self._iterable_methods = defaultdict(lambda: 'next')

        self._is_numeric = self('sub { my $i = shift; (0+$i) eq $i; }')
        self._is_integer = self('sub { my $i = shift; int $i eq $i; }')
        self._ref = self('sub { ref $_[0]; }')

    cdef object _eval(self, object expression, int context):
        cdef int count
        cdef perl.SV* expression_sv = _expression_sv(expression)
        cdef object ret = None

        perl.dSP
        with nogil:
            count = perl.eval_sv(expression_sv, perl.G_EVAL|context)
        perl.SvREFCNT_dec(expression_sv)
        perl.SPAGAIN

        if(context == perl.G_ARRAY):
            ret = [_sv_new(perl.POPs, self) for _ in range(count)]
            ret = ListValue(reversed(ret))
        elif(context == perl.G_SCALAR):
            if(count):
                for _ in range(count - 1):
                    perl.POPs
                ret = _sv_new(perl.POPs, self)
            # if not count, then None is a sensible return value
        elif(context == perl.G_VOID):
            for _ in range(count):
                perl.POPs
        else:
            raise AssertionError("Shouldn't reach here")
        perl.PUTBACK
        if perl.SvTRUE(perl.ERRSV):
            raise RuntimeError(perl.SvPVutf8_nolen(perl.ERRSV).decode())
        else:
            return ret

    def void_context(self, expression):
        return self._eval(expression, perl.G_VOID)

    def scalar_context(self, expression):
        return self._eval(expression, perl.G_SCALAR)

    def list_context(self, expression):
        return self._eval(expression, perl.G_ARRAY)

    def __call__(self, expression):
        return self._eval(expression, perl.G_SCALAR)

    def __getitem__(self, expression):
        return self._eval(expression, perl.G_ARRAY)

    def __getattribute__(self, name):
        """
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i('use Data::Dumper')
        <pyperler.undef>
        >>> print( i.F['Dumper']([1, 2, 2, 3]) )
        $VAR1 = [
                  1,
                  2,
                  2,
                  3
                ];
        <BLANKLINE>
        """
        initial = name[0].upper()
        cdef perl.SV *scalar_value
        cdef perl.AV *array_value
        cdef perl.HV *hash_value
        short_name = str(name[1:]).encode()
        if initial in 'SD':
            scalar_value = perl.get_sv(short_name, 0)
            if scalar_value:
                return _sv_new(scalar_value, self)
            else:
                raise NameError("name '$%s' is not defined" % name[1:])
        elif initial == 'A':
            array_value = perl.get_av(short_name, 0)
            if array_value:
                return _sv_new(perl.newRV_inc(<perl.SV*>array_value), self)
            else:
                raise NameError("name '@%s' is not defined" % name[1:])
        elif initial in 'PH': 
            hash_value = perl.get_hv(short_name, 0)
            if hash_value:
                return _sv_new(perl.newRV_inc(<perl.SV*>hash_value), self)
            else:
                raise NameError("name '%%%s' is not defined" % name[1:])
        elif initial == 'F':
            if len(name) > 1:
                return FunctionAttribute(self, name[1:])
            else:
                class FunctionLookup(object):
                    def __getitem__(this, key):
                        return FunctionAttribute(self, key)
                    def __call__(this, key):
                        raise RuntimeError("You can't use .F(...); use .F[...] instead")
                return FunctionLookup()
        elif name == 'use':
            def perl_package_constructor(*args, **kwds):
                return PerlPackage(self, *args, **kwds)
            return perl_package_constructor
        else:
            return object.__getattribute__(self, name)

    def __dir__(self):
        return ['use', 'A', 'P', 'H', 'F']

    def __setattr__(self, name, value):
        """
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i.Sa = 3
        >>> i.Sa
        3
        >>> i.Sb = 2.3
        >>> i.Sb
        2.3
        >>> i.Aa = [1,2,3]
        >>> len(i.Aa)
        3
        >>> i.Aa[1]
        2
        >>> i.Ha = {1:'2',2:'3'}
        >>> sorted(i.Ha.to_python().values())
        [2, 3]
        >>> i.Ha[2]
        3
        """
        initial = name[0].upper()
        short_name = str(name[1:]).encode()
        cdef perl.SV *sv
        cdef perl.AV *array_value
        cdef perl.HV *hash_value
        if initial in 'SD':
            sv = perl.get_sv(short_name, perl.GV_ADD)
            _assign_sv(sv, value)
        elif initial == 'A':
            array_value = perl.get_av(short_name, perl.GV_ADD)
            perl.av_clear(array_value)
            for element in value:
                perl.av_push(array_value, _new_sv_from_object(element))
        elif initial in 'PH':
            hash_value = perl.get_hv(short_name, perl.GV_ADD)
            perl.hv_clear(hash_value)
            for k, v in value.items():
                k = str(k).encode()
            for k, v in value.iteritems():
                k = str(k).encode()
                perl.hv_store(hash_value, k, len(k), _new_sv_from_object(v), 0)
        else:
            object.__setattr__(self, name, value)

cdef class PerlPackage:
    cdef Interpreter _interpreter
    cdef object _name
    def __init__(self, interpreter, name, iterable_method='next'):
        self._interpreter = interpreter
        self._interpreter._iterable_methods[name] = iterable_method
        self._name = name
        try:
            interpreter('use ' + name)
        except RuntimeError as e:
            raise ImportError("Could not import Perl package %s: %s" % (self._name, e.message))

    def __call__(self, *args, **kwds):
        cdef BoundMethod bound_method = BoundMethod()
        bound_method._method = "new"
        bound_method._sv = _new_sv_from_object(str(self._name))
        bound_method._interpreter = self._interpreter
        return bound_method(*args, **kwds)

    def __getattr__(self, name):
        cdef BoundMethod bound_method = BoundMethod()
        bound_method._method = name
        bound_method._sv = _new_sv_from_object(str(self._name))
        bound_method._interpreter = self._interpreter
        return bound_method

    def __dir__(self):
        try:
            Inspector = self._interpreter.use('Class::Inspector')
            return [str(method) for method in Inspector.methods(self._name)]
        except (ImportError, TypeError):
            return []

class ListValue(tuple):
    def ints(self):
        return tuple(int(x) for x in self)

    def floats(self):
        return tuple(float(x) for x in self)

    def strings(self):
        return tuple(str(x) for x in self)

cdef class FunctionAttribute(object):
    cdef object _name
    cdef Interpreter _interpreter
    def __init__(self, interpreter, name):
        self._name = name
        self._interpreter = interpreter

    def __call__(self, *args, **kwds):
        return call_sub(perl.G_SCALAR, self._name, None, self._interpreter, <perl.SV*>0, <perl.SV*>0, args, kwds)

    def scalar_context(self, *args, **kwds):
        return call_sub(perl.G_SCALAR, self._name, None, self._interpreter, <perl.SV*>0, <perl.SV*>0, args, kwds)

    def list_context(self, *args, **kwds):
        return call_sub(perl.G_ARRAY, self._name, None, self._interpreter, <perl.SV*>0, <perl.SV*>0, args, kwds)

    def void_context(self, *args, **kwds):
        return call_sub(perl.G_VOID, self._name, None, self._interpreter, <perl.SV*>0, <perl.SV*>0, args, kwds)

cdef _sv_new(perl.SV *sv, object interpreter):
    cdef perl.MAGIC* magic
    if(perl.SvROK(sv) and perl.sv_derived_from(sv, "Python::Object")):
        sv = perl.SvRV(sv)
        magic = perl.mg_find(sv, <int>('~'))
        if(magic and magic[0].mg_virtual == &virtual_table):
            obj = <object><void*>perl.SvIVX(sv)
            return obj
    if sv:
        ret = ScalarValue()
        ret._interpreter = interpreter
        ret._sv = perl.SvREFCNT_inc(sv)
        return ret
    else:
        return None

cdef int _free(perl.SV* sv, perl.MAGIC* mg):
    obj = <object><void*>perl.SvIVX(sv)
    del obj
    return 0

cdef perl.MGVTBL virtual_table
virtual_table.svt_free = _free

cdef perl.SV *_new_sv_from_object(object value):
    cdef perl.SV* scalar_value
    cdef perl.SV* ref_value

    cdef perl.AV* array_value
    cdef perl.HV* hash_value
    
    cdef perl.MAGIC* magic

    try:
        if isinstance(value, int):
            return perl.newSViv(value)
        elif isinstance(value, float):
            return perl.newSVnv(value)
        elif isinstance(value, str):
            value = value.encode()
            return perl.newSVpvn_utf8(value, len(value), True)
        elif isinstance(value, bool):
            if value:
                return perl.newSViv(1)
            else:
                return perl.newSVpvn_utf8('', 0, True)
        elif isinstance(value, dict):
            hash_value = perl.newHV()
            for k, v in value.items():
                k = str(k).encode()
                perl.hv_store(hash_value, k, len(k), _new_sv_from_object(v), 0)
            return perl.newRV_noinc(<perl.SV*>hash_value)
        elif isinstance(value, ScalarValue):
            return perl.SvREFCNT_inc((<ScalarValue>value)._sv)
        elif isinstance(value, (list, tuple, xrange)):
            array_value = perl.newAV()
            for i in value:
                perl.av_push(array_value, _new_sv_from_object(i))
            return perl.newRV_noinc(<perl.SV*>array_value)
        else:
            ref_value = perl.newSV(0);
            scalar_value = perl.newSVrv(ref_value, "Python::Object");
            Py_XINCREF(<PyObject*>value)
            perl.SvIV_set(scalar_value, <perl.IV><void*>value)
            
            perl.sv_magic(scalar_value, scalar_value, <int>('~'), <char*>0, 0)
            magic = perl.mg_find(scalar_value, <int>('~'))
            magic[0].mg_virtual = &virtual_table

            #perl.SvREADONLY(scalar_value)
            return ref_value
    except:
        return &perl.PL_sv_undef

cdef _assign_sv(perl.SV *sv, object value):
    if value is None:
        sv = &perl.PL_sv_undef
    elif isinstance(value, int):
        perl.SvSetSV(sv, perl.newSViv(value))
    elif isinstance(value, float):
        perl.SvSetSV(sv, perl.newSVnv(value))
    elif isinstance(value, ScalarValue):
        perl.SvSetSV_nosteal(sv, (<ScalarValue>value)._sv)
    else:
        perl.SvSetSV(sv, _new_sv_from_object(value))

cdef class ScalarValue:
    """
    >>> import pyperler; i = pyperler.Interpreter()
    >>> i.Sa = 3
    >>> i.Sb = 3
    >>> i.Sa == i.Sb
    Traceback (most recent call last):
    ...
    TypeError: Cannot use comparison operator on two perl scalar values '3' and '3'. Convert either one to string or to integer
    >>> i.Sa == 3
    True
    >>> 3 == i.Sb
    True
    >>> 4 == i.Sb
    False
    >>> i.Sa == 4
    False
    >>> i.Sa == 3.001
    False
    >>> i.Sa < 3.001
    True
    >>> i.Sa > 3.001
    False
    >>> 3 < i.Sa
    False
    >>> 3 <= i.Sa
    True
    """
    cdef perl.SV *_sv
    cdef Interpreter _interpreter

    def __dealloc__(self):
        perl.SvREFCNT_dec(self._sv)

    def to_python(self, numeric_if_possible=True, force_scalar_to=None):
        r"""
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i('$a = 3')
        3
        >>> type(i.Sa.to_python()) is int
        True
        >>> i('@a = (1,2,3,4)')
        4
        >>> type(i.Aa.to_python()) is list
        True
        >>> i('%a = (a => 3, b => 4)')
        4
        >>> type(i.Ha.to_python()) is dict
        True
        >>> i('$b = undef')
        <pyperler.undef>
        >>> type(i.Sb.to_python()) is type(None)
        True
        >>> i('$c = "4.5"')
        '4.5'
        >>> type(i.Sc.to_python()) is float
        True
        >>> i('$d = "-4"')
        '-4'
        >>> type(i.Sd.to_python()) is int
        True
        >>> i('$e = "-4"')
        '-4'
        >>> type(i.Se.to_python(numeric_if_possible=False)) is str
        True
        >>> i.Se.to_python(force_scalar_to=float)
        -4.0
        >>> i('$f = "hello, world"')
        'hello, world'
        >>> i.Sf.to_python()
        'hello, world'
        >>> i.Sf.to_python(force_scalar_to=int)
        0
        """
        cdef perl.SV* ref_value
        if not perl.SvOK(self._sv):
            return None
        if perl.SvROK(self._sv):
            ref_value = perl.SvRV(self._sv)
            if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
                return [x.to_python(numeric_if_possible, force_scalar_to) if isinstance(x, ScalarValue) else x for x in self]
            if perl.SvTYPE(ref_value) == perl.SVt_PVHV:
                return {(k.to_python(numeric_if_possible, force_scalar_to) if isinstance(k, ScalarValue) else k):
                        (v.to_python(numeric_if_possible, force_scalar_to) if isinstance(v, ScalarValue) else v) for k,v in self.items()}
        if force_scalar_to is not None:
            return force_scalar_to(self)

        if numeric_if_possible:
            if self._interpreter._is_numeric(self):
                if self._interpreter._is_integer(self):
                    return int(self)
                else:
                    return float(self)
        return str(self)

    def __str__(self):
        u"""
        Do some checks about copying the string, and accurate refcounting:

        >>> import pyperler; i = pyperler.Interpreter()
        >>> i.Sa = "abc" + str(type(i)).replace('type ','').replace('class ','')  # i.Sa is assigned a temporary string object
        >>> i.Sa
        "abc<'pyperler.Interpreter'>"
        >>> text = str(i.Sa)
        >>> i.Sa = "def"
        >>> text[:3]
        'abc'
        >>> i.Sa
        'def'
        """
        cdef size_t length = 0
        cdef char *buffer = perl.SvPVutf8(self._sv, length)
        return bytes(buffer[:length]).decode()

    def __bytes__(self):
        cdef size_t length = 0
        cdef char *buffer = perl.SvPVbyte(self._sv, length)
        return bytes(buffer[:length])

    def __int__(self):
        return <long>perl.SvIV(self._sv)

    def __index__(self):
        return int(self)

    def __float__(self):
        return <double>perl.SvNV(self._sv)

    def __pow__(self, e, z):
        return int(self)**e

    def __repr__(self):
        cdef size_t length = 0
        cdef perl.SV* ref_value
        if perl.SvOK(self._sv):
            if perl.SvROK(self._sv):
                ref_value = perl.SvRV(self._sv)
                if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
                    return repr(list(self))
                else:
                    return repr(self.to_dict())
            if perl.SvIOK(self._sv):
                return repr(int(self))
            if perl.SvNOK(self._sv):
                return repr(float(self))
            else:
                b = bytes(self)
                if PY_MAJOR_VERSION < 3:
                    return repr(b)
                else:
                    try:
                        return repr(b.decode())
                    except UnicodeDecodeError as e:
                        return repr(b)
        else:
            return '<pyperler.undef>'

    def is_defined(self):
        return perl.SvOK(self._sv)

    def __len__(self):
        cdef perl.AV* array_value
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            return len(str(self))
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            array_value = <perl.AV*>ref_value
            if array_value:
                return perl.av_len(array_value) + 1
            else:
                raise RuntimeError()
        else:
            raise TypeError("not an array ref")

    def __nonzero__(self):
        """
        >>> import pyperler; i = pyperler.Interpreter()
        >>> bool(i('12'))
        True
        >>> bool(i('""'))
        False
        >>> i('@array = ()')
        0
        >>> bool(i.Aarray)
        False
        >>> i.Aarray = [1, 2, 3]
        >>> bool(i.Aarray)
        True
        """
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            return perl.SvTRUE(self._sv)
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            return len(self) > 0
        elif perl.SvTYPE(ref_value) == perl.SVt_PVHV:
            # FIXME: we shouldn't allocate the keys list here
            return len(self.keys()) > 0

    def __add__(x, y):
        """
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i.Sa = 3
        >>> i.Sa + 3
        6
        >>> i.Sa + " beers please"
        '3 beers please'
        >>> 'My favourite number is ' + i.Sa
        'My favourite number is 3'
        >>> 8 + i.Sa
        11
        >>> i.Sb = [1,2,3]
        >>> i.Sb + [4, 5]
        [1, 2, 3, 4, 5]
        >>> [0] + i.Sb
        [0, 1, 2, 3]
        >>> i.Sb = "Three"
        >>> i.Sb + " beers please"
        'Three beers please'
        """

        if isinstance(y, str):
            return str(x) + y
        if isinstance(x, str):
            return x + str(y)
        if isinstance(y, (list, tuple, xrange)) or isinstance(x, (list, tuple, xrange)):
            return list(x) + list(y)
        if not isinstance(x, ScalarValue):
            x, y = y, x
        if isinstance(y, (int, float)):
            if perl.SvIOK((<ScalarValue>x)._sv):
                return int(x) + y
            if perl.SvNOK((<ScalarValue>x)._sv):
                return float(x) + y
            # huh?
            return int(x) + y
        if isinstance(y, ScalarValue):
            raise RuntimeError("Cannot use + operator on two perl scalar values '%s' and '%s'. Convert either one to string or to integer" % (x, y))
        raise NotImplementedError("Cannot use + operator on two items of types '%s' and '%s'" %(type(x), type(y)))

    def __sub__(x, y):
        """
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i.Sa = 3
        >>> i.Sa - 2
        1
        >>> i.Sa - 5
        -2
        >>> 8 - i.Sa
        5
        """
        sign = 1
        if not isinstance(x, ScalarValue):
            x, y = y, x
            sign = -1
        if isinstance(y, (int, float)):
            if perl.SvIOK((<ScalarValue>x)._sv):
                return sign*(int(x) - y)
            if perl.SvNOK((<ScalarValue>x)._sv):
                return sign*(float(x) - y)
        if isinstance(y, ScalarValue):
            if perl.SvIOK((<ScalarValue>x)._sv) and perl.SvIOK((<ScalarValue>x)._sv):
                return sign*(int(x) - int(y))
            else:
                return sign*(float(x) - float(y))
        raise NotImplementedError()

    def __mul__(x, y):
        """
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i.Sa = 3
        >>> i.Sa * 3
        9
        >>> 8 * i.Sa
        24
        >>> i.Aa = [1,2,3]
        >>> i.Aa * 3
        [1, 2, 3, 1, 2, 3, 1, 2, 3]
        >>> 3 * i.Aa
        [1, 2, 3, 1, 2, 3, 1, 2, 3]
        """
        if isinstance(y, ScalarValue):
            if perl.SvIOK((<ScalarValue>y)._sv):
                return x * int(y)
            if perl.SvNOK((<ScalarValue>y)._sv):
                return x * float(y)
            if perl.SvROK((<ScalarValue>y)._sv):
                return x * list(y)
        if isinstance(y, (int, float)):
            if perl.SvIOK((<ScalarValue>x)._sv):
                return int(x) * y
            if perl.SvNOK((<ScalarValue>x)._sv):
                return float(x) * y
            if perl.SvROK((<ScalarValue>x)._sv):
                return list(x) * y
        raise NotImplementedError()

    def __div__(x, y):
        return x.__floordiv__(y)

    def __floordiv__(x, y):
        """
        >>> import pyperler; i = pyperler.Interpreter()
        >>> from operator import floordiv
        >>> i.Sa = 3
        >>> floordiv(i.Sa, 3)
        1
        >>> #8 / i.Sa
        2
        >>> i.Sb = 10
        >>> floordiv(i.Sb, i.Sa)
        3
        """
        from operator import floordiv
        if isinstance(y, ScalarValue):
            if perl.SvIOK((<ScalarValue>y)._sv):
                return floordiv(x, int(y))
            if perl.SvNOK((<ScalarValue>y)._sv):
                return floordiv(x, float(y))
        if isinstance(y, (int, float)):
            if perl.SvIOK((<ScalarValue>x)._sv):
                return floordiv(int(x), y)
            if perl.SvNOK((<ScalarValue>x)._sv):
                return floordiv(float(x), y)
        raise NotImplementedError()

    def __truediv__(x, y):
        """
        >>> import pyperler; i = pyperler.Interpreter()
        >>> from operator import truediv
        >>> i.Sa = 3
        >>> truediv(i.Sa, 3)
        1.0
        >>> truediv(8, i.Sa)
        2.6666666666666665
        >>> i.Sb = 10
        >>> truediv(i.Sb, i.Sa)
        3.3333333333333335
        """
        from operator import truediv
        if isinstance(y, ScalarValue):
            if perl.SvIOK((<ScalarValue>y)._sv):
                return truediv(x, int(y))
            if perl.SvNOK((<ScalarValue>y)._sv):
                return truediv(x, float(y))
        if isinstance(y, (int, float)):
            if perl.SvIOK((<ScalarValue>x)._sv):
                return truediv(int(x), y)
            if perl.SvNOK((<ScalarValue>x)._sv):
                return truediv(float(x) / y)
        raise NotImplementedError()
    #def __mod__(x, y):
    #def __divmod__(x, y):
    #def __pow__(x, y, z):
    #def __neg__(self):
    #def __pos__(self):
    #def __abs__(self):
    #def __invert__(x, y):
    #def __lshift__(x, y):
    #def __rshift__(x, y):
    #def __and__(x, y):
    #def __or__(x, y):
    #def __xor__(x, y):
    def __richcmp__(x, y, operation):
        import operator
        op = { 0: operator.lt, 2: operator.eq, 4: operator.gt, 1: operator.le, 3: operator.ne, 5: operator.ge}[operation]
        if isinstance(y, ScalarValue):
            raise TypeError("Cannot use comparison operator on two perl scalar values '%s' and '%s'. Convert either one to string or to integer" % (x, y))
        if y is None:
            return op(x.to_python(), y)
        if isinstance(y, (int, float, str, bytes)):
            return op(type(y)(x), y)
        raise NotImplementedError()

    def __iter__(self):
        cdef perl.SV** scalar_value
        cdef perl.AV* array_value
        cdef perl.HV* hash_value
        cdef perl.SV* ref_value
        cdef int count
        cdef char* key
        cdef int retlen
        if not perl.SvROK(self._sv):
            raise TypeError("not an array or hash")
        package = self.blessed_package()
        if package:
            method = self._interpreter._iterable_methods[package]
            next_ = getattr(self, method)
            item = next_()
            while item:
                yield item
                item = next_()
            return
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            for ix in xrange(len(self)):
                yield self[ix]
        elif perl.SvTYPE(ref_value) == perl.SVt_PVHV:
            hash_value = <perl.HV*>ref_value
            count = perl.hv_iterinit(hash_value)
            for i in range(count):
                sv = perl.hv_iternextsv(hash_value, &key, &retlen)
                yield bytes(key).decode()

    def items(self):
        cdef perl.SV* ref_value
        cdef perl.HV* hash_value
        cdef int count
        cdef char* key
        cdef int retlen
        if not perl.SvROK(self._sv):
            raise TypeError("not a hash")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVHV:
            hash_value = <perl.HV*>ref_value
            count = perl.hv_iterinit(hash_value)
            for i in range(count):
                sv = perl.hv_iternextsv(hash_value, &key, &retlen)
                yield bytes(key).decode(), _sv_new(sv, self._interpreter)
        else:
            raise TypeError("not a hash")

    def __getitem__(self, key):
        cdef perl.SV** scalar_value
        cdef perl.AV* array_value
        cdef perl.HV* hash_value
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array or hash")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            array_value = <perl.AV*>ref_value
            scalar_value = perl.av_fetch(array_value, key, False)
            if scalar_value:
                return _sv_new(scalar_value[0], self._interpreter)
            else:
                raise IndexError(key)
        elif perl.SvTYPE(ref_value) == perl.SVt_PVHV:
            hash_value = <perl.HV*>ref_value
            key = str(key).encode()
            scalar_value = perl.hv_fetch(hash_value, key, len(key), False)
            if scalar_value:
                return _sv_new(scalar_value[0], self._interpreter)
            else:
                raise KeyError(key)
        
    def __setitem__(self, key, value):
        cdef perl.SV** scalar_value
        cdef perl.AV* array_value
        cdef perl.HV* hash_value
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array or hash")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            array_value = <perl.AV*>ref_value
            perl.av_store(array_value, key, _new_sv_from_object(value))
        elif perl.SvTYPE(ref_value) == perl.SVt_PVHV:
            hash_value = <perl.HV*>ref_value
            key = str(key).encode()
            perl.hv_store(hash_value, key, len(key), _new_sv_from_object(value), 0)

    def __call__(self, *args, **kwds):
        return call_sub(perl.G_SCALAR, None, None, self._interpreter, self._sv, <perl.SV*>0, args, kwds)

    def scalar_context(self, *args, **kwds):
        return call_sub(perl.G_SCALAR, None, None, self._interpreter, self._sv, <perl.SV*>0, args, kwds)

    def list_context(self, *args, **kwds):
        return call_sub(perl.G_ARRAY, None, None, self._interpreter, self._sv, <perl.SV*>0, args, kwds)

    def void_context(self, *args, **kwds):
        return call_sub(perl.G_VOID, None, None, self._interpreter, self._sv, <perl.SV*>0, args, kwds)

    def __getattr__(self, name):
        """
        >>> import pyperler; i= pyperler.Interpreter()
        >>> arrayref = i('package a; sub append { 42 }; bless [], "a"')
        >>> arrayref.append(23)
        >>> arrayref.F['append'](23)
        42
        """
        if name == 'F':
            class Indexable:
                def __getitem__(this, function_name):
                    ret = BoundMethod()
                    ret._sv = perl.SvREFCNT_inc(self._sv)
                    ret._method = function_name
                    ret._interpreter = self._interpreter
                    return ret
            return Indexable()
        else:
            ret = BoundMethod()
            ret._sv = perl.SvREFCNT_inc(self._sv)
            ret._method = name
            ret._interpreter = self._interpreter
            return ret

    def keys(self):
        return [k for k,v in self.items()]

    def values(self):
        return [v for k,v in self.items()]

    def to_dict(self):
        return {k: v for k,v in self.items()}

    def append(self, element):
        r"""
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i('@array = 1 .. 4')
        4
        >>> i.Aarray.append(11)
        >>> i.Aarray
        [1, 2, 3, 4, 11]
        """
        cdef perl.AV* array_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array or hash")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            array_value = <perl.AV*>ref_value
            perl.av_push(array_value, _new_sv_from_object(element))
        else:
            raise TypeError("not an array or hash")

    def strings(self):
        return tuple(str(_) for _ in self)

    def ints(self):
        return tuple(int(_) for _ in self)

    def floats(self):
        return tuple(float(_) for _ in self)

    def blessed_package(self):
        ref = str(self._interpreter._ref(self))
        if ref != 'HASH' and ref != 'ARRAY':
            return ref
        return None

    def __dir__(self):
        try:
            Inspector = self._interpreter.use('Class::Inspector')
            classname = self.blessed_package()
            return [str(method) for method in Inspector.methods(classname)]
        except (ImportError, TypeError):
            return []

    def clear(self):
        r"""
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i('@array = 1 .. 4')
        4
        >>> i.Aarray.clear()
        >>> i.Aarray
        []
        >>> i('%hash= (a => 1)')
        2
        >>> i.Hhash.clear()
        >>> i.Hhash
        {}
        """
        cdef perl.SV* ref_value
        cdef perl.AV* array_value
        cdef perl.HV* hash_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array or hash")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            array_value = <perl.AV*>ref_value
            perl.av_clear(array_value)
        elif perl.SvTYPE(ref_value) == perl.SVt_PVHV:
            hash_value = <perl.HV*>ref_value
            perl.hv_clear(hash_value)
        else:
            raise TypeError("not an array or hash")

    def copy(self):
        r"""
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i('@array = (1 .. 4)')
        4
        >>> a= i.Aarray.copy()
        >>> a[0]= 0
        >>> a
        [0, 2, 3, 4]
        >>> i.Aarray
        [1, 2, 3, 4]
        >>> i('%hash= (a => 1)')
        2
        >>> h= i.Hhash.copy()
        >>> h['a']= 2
        >>> i.Hhash['a']
        1
        """
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array or hash")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            return list(self)
        elif perl.SvTYPE(ref_value) == perl.SVt_PVHV:
            return { k: v for k,v in self.items() }
        else:
            raise TypeError("not an array or hash")

    def count(self, value):
        r"""
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i('@array = (1,1,1,2,3)')
        5
        >>> i.Aarray.count(1)
        3
        """
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            cnt= 0
            for x in self:
                if x == value:
                    cnt+= 1
            return cnt
        else:
            raise TypeError("not an array")

    def extend(self, iterable):
        r"""
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i('@array = (1 .. 4)')
        4
        >>> i.Aarray.extend(range(5,7))
        >>> i.Aarray
        [1, 2, 3, 4, 5, 6]
        """
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            for x in iterable:
                self.append(x)
        else:
            raise TypeError("not an array")

    def index(self, value, start=None, stop=None):
        r"""
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i('@array = (1 .. 4)')
        4
        >>> i.Aarray.index(3)
        2
        >>> i.Aarray.index(3, 1)
        2
        >>> i.Aarray.index(3, 1, 4)
        2
        >>> i.Aarray.index(3, 1, 1) # doctest: +ELLIPSIS
        Traceback (most recent call last):
        ...
        ValueError: 3 is not in list
        """
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
            if start is None:
                start= 0
            if stop is None:
                stop= len(self)
            for ix in range(start, stop):
                if self[ix] == value:
                    return ix
            raise ValueError("%s is not in list" % value)
        else:
            raise TypeError("not an array")

    def insert(self, index, value):
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) != perl.SVt_PVAV:
            raise TypeError("not an array")
        cdef perl.AV* array_value = <perl.AV*>ref_value
        cdef int old_size = perl.av_top_index(array_value) + 1
        cdef int new_size = old_size + 1
        perl.av_fill(array_value, perl.av_top_index(array_value)+1)
        cdef int i
        cdef perl.SV** tmp
        for i in range(1, old_size - index + 1):
            tmp= perl.av_fetch(array_value, old_size - i, False)
            perl.SvREFCNT_inc(tmp[0])
            perl.av_store(array_value, new_size - i, tmp[0])
        perl.av_store(array_value, min(index, old_size), _new_sv_from_object(value))

    def pop(self, index=None):
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) != perl.SVt_PVAV:
            raise TypeError("not an array")
        cdef perl.AV* array_value = <perl.AV*>ref_value

        # can't use perl.av_pop because it has different
        # semantics for empty arrays / index out of range
        if(index is None):
            index = len(self) - 1
        if index >= len(self):
            raise IndexError("Index out of bounds")

        cdef int old_size = perl.av_top_index(array_value) + 1
        cdef int new_size = old_size - 1
        cdef int i
        cdef perl.SV** tmp

        tmp= perl.av_fetch(array_value, index, False)
        cdef object ret= _sv_new(tmp[0], self._interpreter)
        for i in range(0, new_size - index):
            tmp= perl.av_fetch(array_value, index + i + 1, False)
            perl.SvREFCNT_inc(tmp[0])
            perl.av_store(array_value, index + i, tmp[0])
        perl.av_fill(array_value, new_size - 1)

        return ret

    def remove(self, value):
        try:
            self.pop(self.index(value))
        except IndexError:
            raise ValueError("Value not found")

    def reverse(self):
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) != perl.SVt_PVAV:
            raise TypeError("not an array")
        cdef perl.AV* array_value = <perl.AV*>ref_value

        cdef size_t size = perl.av_top_index(array_value)+1
        cdef perl.SV** left
        cdef perl.SV** right
        cdef perl.SV* tmp
        cdef size_t i
        for i in range(size>>1):
            left= perl.av_fetch(array_value, i, False)
            right= perl.av_fetch(array_value, size - 1 - i, False)
            tmp= left[0]
            left[0]= right[0]
            right[0]= tmp

    def sort(self, key=None, reverse=False):
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array")
        ref_value = perl.SvRV(self._sv)
        if perl.SvTYPE(ref_value) != perl.SVt_PVAV:
            raise TypeError("not an array")
        cdef perl.AV* array_value = <perl.AV*>ref_value

        def sort_key(ix):
            if key:
                return key(self[ix])
            else:
                return self[ix]

        indices= list(range(len(self)))
        indices.sort(key=sort_key, reverse=reverse)

        to_permute=set(range(len(self)))
        cdef perl.SV** target
        cdef perl.SV** source
        cdef perl.SV* temp
        while to_permute:
            ix= to_permute.pop()
            target= perl.av_fetch(array_value, ix, False)
            temp= target[0]
            while indices[ix] in to_permute:
                source= perl.av_fetch(array_value, indices[ix], False)
                target[0]= source[0]
                target= source
                ix = indices[ix]
                to_permute.remove(ix)
            target[0]= temp


cdef class BoundMethod(object):
    cdef perl.SV *_sv
    cdef object _method
    cdef Interpreter _interpreter

    def __call__(self, *args, **kwds):
        return call_sub(perl.G_SCALAR, None, self._method, self._interpreter, <perl.SV*>0, self._sv, args, kwds)
    
    def __dealloc__(self):
        perl.SvREFCNT_dec(self._sv)

    def scalar_context(self, *args, **kwds):
        return call_sub(perl.G_SCALAR, None, self._method, self._interpreter, <perl.SV*>0, self._sv, args, kwds)

    def list_context(self, *args, **kwds):
        return call_sub(perl.G_ARRAY, None, self._method, self._interpreter, <perl.SV*>0, self._sv, args, kwds)

    def void_context(self, *args, **kwds):
        return call_sub(perl.G_VOID, None, self._method, self._interpreter, <perl.SV*>0, self._sv, args, kwds)

    def __getattribute__(self, name):
        if name == '__doc__':
            return self._docstring(self._method)
        return object.__getattribute__(self, name)

    def _docstring(self, name):
        try:
            Inspector = self._interpreter.use('Class::Inspector')
            classname = str(self._interpreter['sub { ref $_[0] || $_[0]; }'](_sv_new(self._sv, self._interpreter)))
            filename = str(Inspector.loaded_filename(classname))
            result = """Documentation for method %s in package %s

Here's the first few lines of this method, which hopefully give you a clue
about its signature:

""" % (name, classname)
            number_of_lines = 0
            for line in open(filename):
                if ('sub ' + self._method) in line:
                    number_of_lines = 10
                if number_of_lines:
                    result += line
                    number_of_lines -= 1
                    if not number_of_lines:
                        break
            return result
        except (ImportError, IOError):
            return "No docstring available; either Class::Inspector is not installed or the source file could not be read"

cdef object call_sub(int context, object name, object method, object interpreter, perl.SV* scalar_value, perl.SV* self, object args, object kwds):
        cdef int count
        cdef int i
        cdef char* name_str
        cdef object ret = None
        perl.dSP
        perl.ENTER
        perl.SAVETMPS

        perl.PUSHMARK(perl.SP)
        if self:
            perl.XPUSHs(self)
        for arg in args:
            perl.mXPUSHs(_new_sv_from_object(arg))
        for k,v in kwds.items():
            perl.mXPUSHs(_new_sv_from_object(k))
            perl.mXPUSHs(_new_sv_from_object(v))
        perl.PUTBACK
        try:
            if self:
                method_str = str(method).encode()
                name_str = method_str
                with nogil:
                    count = perl.call_method(name_str, perl.G_EVAL|context)
            elif name:
                name = str(name).encode()
                name_str = name
                with nogil:
                    count = perl.call_pv(name_str, perl.G_EVAL|context)
            elif scalar_value:
                with nogil:
                    count = perl.call_sv(scalar_value, perl.G_EVAL|context)
            else:
                raise AssertionError("Shouldn't reach here")
            perl.SPAGAIN

            if context == perl.G_ARRAY:
                ret = [_sv_new(perl.POPs, interpreter) for i in range(count)]
                ret = tuple(reversed(ret))
            elif context == perl.G_SCALAR:
                if count:
                    for _ in range(count - 1):
                        perl.POPs
                    ret = _sv_new(perl.POPs, interpreter)
            elif context == perl.G_VOID:
                for _ in range(count):
                    perl.POPs

            if perl.SvTRUE(perl.ERRSV):
                raise RuntimeError(perl.SvPVutf8_nolen(perl.ERRSV).decode())
            else:
                return ret
        finally:
            perl.PUTBACK
            perl.FREETMPS
            perl.LEAVE

import sys,os
PERL_SYS_INIT3(sys.argv, os.environ)

cdef void* handle
if sys.platform.startswith('linux'):
    # we need to reload the perl libary with RTLD_GLOBAL, because many compiled CPAN
    # modules assume that those symbols are available. Python does not import the
    # library's symbols into a global namespace
    handle=dlfcn.dlopen("libperl.so",dlfcn.RTLD_LAZY|dlfcn.RTLD_GLOBAL)
    if(not handle):
        raise RuntimeError("Could not load perl: %s" % dlfcn.dlerror())
