# vim: set fileencoding=utf-8 :
#
# pyperler.pyx
#
# Copyright (C) 2013, Timo Kluck <tkluck@infty.nl>
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
>>> i.Sa
4
>>> i['$a']
4
>>> list(range(i.Sa))
[0, 1, 2, 3]
>>> i.Sa = 5
>>> list(range(i.Sa))
[0, 1, 2, 3, 4]
>>> i['undef']
None

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
>>> int(i["@array"])
5

which is also available from Python:
>>> len(i.Aarray)
5

Fun with Perl's secret operators:
>>> i["()= qw / a b c d e /"]
5

Accessing array values:
>>> i("@d = (10 .. 20)")
>>> i.Ad.ints()
(10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20)
>>> i.Ad[2]
12
>>> list(i.Ad)[2]
12
>>> i.Ad[0] = 9
>>> int(i['$d[0]'])
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
>>> list(i.Aletters)
['P', 'e', 'r', 'l', ' ', 'i', 'n', ' ', 'P', 'y', 't', 'h', 'o', 'n']

Accessing hash values:
>>> i("%b = (greece => 'Aristotle', germany => 'Hegel');")
>>> i.Pb.dict()
{u'germany': 'Hegel', u'greece': 'Aristotle'}
>>> i.Pb['greece']
'Aristotle'
>>> i.Pb['germany'] = 'Kant'
>>> i('$c = $b{germany}')
>>> i.Sc
'Kant'
>>> i.Pparrot = {'dead': True}
>>> i["$parrot{dead}"]
1

Accessing objects (we assign to _ to discard the meaningless return values):
>>> i("unshift @INC, './perllib'")
>>> i("use Car; $car = Car->new")
>>> _ = i.Scar.set_brand("Toyota")
>>> _ = i.Scar.drive(20)
>>> i["$car->distance"]
20
>>> int(i.Scar.distance())
20
>>> i.Scar.drive(20)

Verify that this makes the intended change to the object:
>>> i["$car->distance"]
40
>>> int(i.Scar.distance())
40

Catching perl exceptions ('die'):
>>> i.Scar.out_of_gas() # doctest: +ELLIPSIS
Traceback (most recent call last):
...
RuntimeError: Out of gas! at perllib/Car.pm line ...
<BLANKLINE>

Nested structures:
>>> i("$a = { dictionary => { a => 65, b => 66 }, array => [ 4, 5, 6] }")
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
>>> int(i['$a->{dictionary}->{c}'])
67
>>> i['keys %{ $a->{dictionary} } '].strings()
('c', 'd')

Calling subs:
>>> i("sub do_something { for (1..10) { 2 + 2 }; return 3; }")
>>> i.Fdo_something()
3
>>> i("sub add_two { return $_[0] + 2; }")
>>> i.Fadd_two("4")
6

Anonymous subs:
>>> i['sub { return 2*$_[0]; }'](6)
12

In packages:
>>> i.F['Car::all_brands']()
('Toyota', 'Nissan')

Passing a Perl function as a callback to python. You'll need to
specify whether you want it to evaluate in scalar context or
list context:
>>> def long_computation(on_ready):
...     for i in range(10**5): 2 + 2
...     return on_ready(5)
...
>>> long_computation(i['sub { return 4; }'].scalar_context)
4
>>> i('sub callback { return $_[0]; }');
>>> long_computation(i.Fcallback.scalar_context)
5

You can maintain a reference to a Perl object, without it being
a Perl variable:
>>> car = i['Car->new'].result(False)
>>> _ = car.set_brand('Chevrolet')
>>> _ = car.drive(20)
>>> car.brand()
'Chevrolet'
>>> del car   # this deletes it on the Perl side, too

>>> i('sub p { return $_[0] ** $_[1]; }')
>>> i.Fp(2,3)
8.0

But the canonical way is this:
>>> Car = i.use('Car')
>>> car = Car()
>>> _ = car.drive(20)
>>> _ = car.set_brand('Honda')
>>> car.brand()
'Honda'

You can also pass Python functions as Perl callbacks:
>>> def f(): return 3 
>>> i('sub callit { return $_[0]->() }')
>>> i.Fcallit(f)
3
>>> def g(x): return x**2
>>> i('sub pass_three { return $_[0]->(3) }')
>>> i.Fpass_three(g)
9
>>> i('sub call_first { return $_[0]->($_[1]); }')
>>> i.Fcall_first(lambda x: eval(str(x)), "2+2")
4

And this even works if you switch between Perl and Python several times:
>>> i.Fcall_first(i, "2+2") # no lock or segfault

And also when we don't discard the return value:
>>> def h(x): return int(i[x])
>>> i.Fcall_first(h, "2+2")
4

Test that we recover objects when we pass them through perl
>>> class FooBar(object):
...    def __init__(self):
...       self._last_set_item = None
...    def foo(self):
...       return "bar"
...    def __getitem__(self, key):
...         return 'key: %s' % key
...    def __setitem__(self, key, value):
...         self._last_set_item = value
...    def __len__(self):
...         return 31337
...    def __bool__(self):
...         return bool(self._last_set_item)
...
>>> i('sub shifter { shift; }')
>>> foobar = FooBar()
>>> type(foobar)
<class 'pyperler.FooBar'>
>>> type(i.Fshifter(FooBar()))
<class 'pyperler.FooBar'>

And that indexing and getting the length works:
>>> i['sub { return $_[0]->{miss}; }'](foobar)
u'key: miss'
>>> i['sub { $_[0]->{funny_joke} = "dkfjasd"; return undef; }'](foobar)
>>> i['sub { return $_[0] ? "YES" : "no"; }'](foobar)
'YES'
>>> i['sub { return scalar@{ $_[0] }; }'](foobar)
31337

>>> Table = i.use('Text::Table')
>>> t = Table("Planet", "Radius\nkm", "Density\ng/cm^3")
>>> _ = t.load(
...    [ "Mercury", 2360, 3.7 ],
...    [ "Venus", 6110, 5.1 ],
...    [ "Earth", 6378, 5.52 ],
...    [ "Jupiter", 71030, 1.3 ],
... )
>>> print( t.table.scalar_context() )
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
>>> i['sub { shift; }'](2**38)
274877906944

Test using negative numbers:
>>> i['sub { shift; }'](-1)
-1

Test passing blessed scalar values through Python:
>>> i.Sdaewoo_matiz = Car()
>>> i['ref $daewoo_matiz']
'Car'

We even support introspection if your local CPAN installation sports Class::Inspector:
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
>>> i('$numbers = bless [1,2,3], "DummyIterable"')
>>> for a in i.Snumbers:
...     print(a)
...
1
2
3
"""
from libc.stdlib cimport malloc, free
cimport dlfcn
from cpython.string cimport PyString_AsString
from cpython cimport PyObject, Py_XINCREF
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

class Interpreter(object):
    def __init__(self):
        self._interpreter = _PerlInterpreter()
        self._interpreter.parse([b"",b"-e",PythonObjectPackage])
        self._interpreter.run()
        self._iterable_methods = defaultdict(lambda: 'next')

    def __call__(self, code):
        self[str(code)].result(False)

    def __getitem__(self, expression):
        return LazyExpression(self, str(expression))

    def __getattribute__(self, name):
        """
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i('use Data::Dumper')
        >>> print( i.F['Dumper']({1: 2, 2: 3}) )
        $VAR1 = {
                  '1' => 2,
                  '2' => 3
                };
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
                return LazyFunctionVariable(self, name[1:])
            else:
                class FunctionLookup(object):
                    def __getitem__(self, key):
                        return LazyFunctionVariable(self, key)
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
        >>> i.Ha = {1:2,2:3}
        >>> i.Ha.dict()
        {u'1': 2, u'2': 3}
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
            return object.__setattr__(self, name, value)

cdef class PerlPackage:
    cdef object _interpreter
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

cdef class LazyExpression:
    cdef object _interpreter
    cdef object _expression
    cdef bint _evaluated
    def __init__(self, interpreter, expression):
        self._interpreter = interpreter
        self._expression = expression

    def result(self, list_context):
        if self._evaluated: raise RuntimeError("Cannot use lazy expression multiple times")
        self._evaluated = True

        cdef flag = perl.G_ARRAY if list_context else perl.G_SCALAR
        perl.dSP
        cdef int count = perl.eval_sv(self._expression_sv(), perl.G_EVAL|flag)
        perl.SPAGAIN
        ret = [_sv_new(perl.POPs, self._interpreter) for _ in range(count)]
        perl.PUTBACK
        if perl.SvTRUE(perl.ERRSV):
            raise RuntimeError(perl.SvPVutf8_nolen(perl.ERRSV).decode())
        ret = tuple(reversed(ret))
        if(list_context):
            return ret
        else:
            return ret[0]

    cdef perl.SV* _expression_sv(self):
        if isinstance(self._expression, ScalarValue):
            return perl.SvREFCNT_inc((<ScalarValue>self._expression)._sv)
        else:
            expression = str(self._expression).encode()
            return perl.newSVpvn_utf8(expression, len(expression), True)
        
    def __call__(self, *args, **kwds):
        return self.result(False)(*args, **kwds)

    def strings(self):
        return tuple(str(x) for x in self)

    def ints(self):
        return tuple(int(x) for x in self)

    def __iter__(self):
        return iter(self.result(True))

    def __str__(self):
        return str(self.result(False))

    def __int__(self):
        return int(self.result(False))

    def __repr__(self):
        return repr(self.result(False))

    def __cmp__(left, right):
        pass

    def __nonzero__(left):
        pass

    def scalar_context(self, *args, **kwds):
        return self.result(False).scalar_context(*args, **kwds)

    def list_context(self, *args, **kwds):
        return self.result(False).list_context(*args, **kwds)

    def __getattr__(self, name):
        ret = BoundMethod()
        ret._sv = self._expression_sv()
        ret._method = name
        ret._interpreter = self._interpreter
        return ret

cdef class LazyFunctionVariable(object):
    cdef object _name
    cdef object _interpreter
    def __init__(self, interpreter, name):
        self._name = name
        self._interpreter = interpreter

    def __call__(self, *args, **kwds):
        return CalledSub_new(self._name, None, self._interpreter, <perl.SV*>0, <perl.SV*>0, args, kwds)

    def scalar_context(self, *args, **kwds):
        return LazyCalledSub_new(self._name, None, self._interpreter, <perl.SV*>0, <perl.SV*>0, args, kwds).result(False)

    def list_context(self, *args, **kwds):
        return LazyCalledSub_new(self._name, None, self._interpreter, <perl.SV*>0, <perl.SV*>0, args, kwds).result(True)

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
    RuntimeError: Cannot use comparison operator on two perl scalar values '3' and '3'. Convert either one to string or to integer
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
    cdef object _interpreter

    def __dealloc__(self):
        perl.SvREFCNT_dec(self._sv)

    def to_python(self):
        r"""
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i('$a = 3')
        >>> type(i.Sa.to_python()) is int
        True
        >>> i('@a = (1,2,3,4)')
        >>> type(i.Aa.to_python()) is list
        True
        >>> i('%a = (a => 3, b => 4)')
        >>> type(i.Ha.to_python()) is dict
        True
        >>> i('$b = undef')
        >>> type(i.Sb.to_python()) is type(None)
        True
        """
        cdef perl.SV* ref_value
        if not perl.SvOK(self._sv):
            return None
        if perl.SvROK(self._sv):
            ref_value = perl.SvRV(self._sv)
            if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
                return [x.to_python() if isinstance(x, ScalarValue) else x for x in self]
            if perl.SvTYPE(ref_value) == perl.SVt_PVHV:
                return {(k.to_python() if isinstance(k, ScalarValue) else k):
                        (v.to_python() if isinstance(v, ScalarValue) else v) for k,v in self.items()}
        if perl.SvIOK(self._sv):
            return int(self)
        if perl.SvNOK(self._sv):
            return float(self)
        return str(self)

    def __str__(self):
        u"""
        Do some checks about copying the string, and accurate refcounting:

        >>> import pyperler; i = pyperler.Interpreter()
        >>> i.Sa = "abc" + str(type(i))   # i.Sa is assigned a temporary string object
        >>> i.Sa
        "abc<class 'pyperler.Interpreter'>"
        >>> text = str(i.Sa)
        >>> i.Sa = "def"
        >>> text[:3]
        'abc'
        >>> i.Sa
        'def'
        """
        cdef int length = 0
        cdef char *perl_string = perl.SvPVutf8(self._sv, length)
        return perl_string[:length].decode()

    def __int__(self):
        return <long>perl.SvIV(self._sv)

    def __index__(self):
        return int(self)

    def __float__(self):
        return <double>perl.SvNV(self._sv)

    def __pow__(self, e, z):
        return int(self)**e

    def __repr__(self):
        cdef perl.SV* ref_value
        if perl.SvOK(self._sv):
            if perl.SvROK(self._sv):
                ref_value = perl.SvRV(self._sv)
                if perl.SvTYPE(ref_value) == perl.SVt_PVAV:
                    return repr(list(self))
                else:
                    return repr(self.dict())
            if perl.SvIOK(self._sv):
                return repr(int(self))
            if perl.SvNOK(self._sv):
                return repr(float(self))
            else:
                return repr(str(self))
        else:
            return 'None'

    def is_defined(self):
        return perl.SvOK(self._sv)

    def __len__(self):
        cdef perl.AV* array_value
        cdef perl.SV* ref_value
        if not perl.SvROK(self._sv):
            raise TypeError("not an array ref")
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
        >>> bool(i['12'].result(False))
        True
        >>> bool(i['""'].result(False))
        False
        >>> i('@array = ()')
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

    def __hash__(self):
        return int(<long>self._sv)

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
        if isinstance(y, ScalarValue):
            raise RuntimeError("Cannot use + operator on two perl scalar values '%s' and '%s'. Convert either one to string or to integer" % (x, y))
        raise NotImplementedError()

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
        >>> i.Sa = 3
        >>> i.Sa / 3
        1
        >>> #8 / i.Sa
        2
        >>> i.Sb = 10
        >>> i.Sb / i.Sa
        3
        """
        if isinstance(y, ScalarValue):
            if perl.SvIOK((<ScalarValue>y)._sv):
                return x / int(y)
            if perl.SvNOK((<ScalarValue>y)._sv):
                return x / float(y)
        if isinstance(y, (int, float)):
            if perl.SvIOK((<ScalarValue>x)._sv):
                return int(x) / y
            if perl.SvNOK((<ScalarValue>x)._sv):
                return float(x) / y
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
            raise RuntimeError("Cannot use comparison operator on two perl scalar values '%s' and '%s'. Convert either one to string or to integer" % (x, y))
        if y is None:
            return op(x.to_python(), y)
        if isinstance(y, (int, float, str)):
            return op(type(y)(x), y)
        raise NotImplementedError()

    def __hash__(self):
        r"""
        >>> import pyperler; i = pyperler.Interpreter()
        >>> i.Sa = 3
        >>> d = {i.Sa: "test"}
        >>> d[3]
        'test'
        >>> i.Sb = None
        >>> d[i.Sb] = 19
        >>> d[None]
        19
        """
        if not perl.SvOK(self._sv):
            return hash(None)
        if perl.SvIOK(self._sv):
            return hash(int(self))
        if perl.SvNOK(self._sv):
            return hash(float(self))
        if perl.SvROK(self._sv):
            raise NotImplementedError("Mutable types are not hashable")
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
        return CalledSub_new(None, None, self._interpreter, self._sv, <perl.SV*>0, args, kwds)

    def scalar_context(self, *args, **kwds):
        return LazyCalledSub_new(None, None, self._interpreter, self._sv, <perl.SV*>0, args, kwds).result(False)

    def list_context(self, *args, **kwds):
        return LazyCalledSub_new(None, None, self._interpreter, self._sv, <perl.SV*>0, args, kwds).result(True)

    def __getattr__(self, name):
        ret = BoundMethod()
        ret._sv = perl.SvREFCNT_inc(self._sv)
        ret._method = name
        ret._interpreter = self._interpreter
        return ret

    def dict(self):
        """
            >>> import pyperler; i = pyperler.Interpreter()
            >>> i['{a => 1, b => 2}'].result(False).dict()
            {u'a': 1, u'b': 2}
        """
        return {key: value for key, value in self.items()}

    def keys(self):
        return self.dict().keys()

    def values(self):
        return self.dict().values()

    def strings(self):
        return tuple(str(_) for _ in self)

    def ints(self):
        return tuple(int(_) for _ in self)

    def blessed_package(self):
        ref = str(self._interpreter['sub { ref $_[0]; }'](self))
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
        

cdef class BoundMethod(object):
    cdef perl.SV *_sv
    cdef object _method
    cdef object _interpreter

    def __call__(self, *args, **kwds):
        return CalledSub_new(None, self._method, self._interpreter, <perl.SV*>0, self._sv, args, kwds)
    
    def __dealloc__(self):
        perl.SvREFCNT_dec(self._sv)

    def scalar_context(self, *args, **kwds):
        return LazyCalledSub_new(None, self._method, self._interpreter, <perl.SV*>0, self._sv, args, kwds).result(False)

    def list_context(self, *args, **kwds):
        return LazyCalledSub_new(None, self._method, self._interpreter, <perl.SV*>0, self._sv, args, kwds).result(True)

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

cdef object CalledSub_new(object name, object method, object interpreter, perl.SV* scalar_value, perl.SV* self, object args, object kwds):
    cdef LazyCalledSub ret = LazyCalledSub_new(name, method, interpreter, scalar_value, self, args, kwds)
    result = ret.result(True)
    if len(result) == 1:
        result = result[0]
        if isinstance(result, ScalarValue) and not result.is_defined():
            return None
        return result
    return result

cdef object LazyCalledSub_new(object name, object method, object interpreter, perl.SV* scalar_value, perl.SV* self, object args, object kwds):
    cdef LazyCalledSub ret = LazyCalledSub()
    ret._name = name
    ret._method = method
    ret._interpreter = interpreter
    ret._sv = perl.SvREFCNT_inc(scalar_value)
    ret._self = perl.SvREFCNT_inc(self)
    ret._args = args
    ret._kwds = kwds
    return ret

cdef class LazyCalledSub:
    cdef object _name
    cdef object _method
    cdef object _interpreter
    cdef perl.SV* _sv

    cdef perl.SV *_self
    cdef object _args
    cdef object _kwds
    cdef bint _evaluated

    def result(self, list_context):
        if self._evaluated: raise RuntimeError("Cannot use lazy expression multiple times")
        self._evaluated = True

        cdef flag = perl.G_ARRAY if list_context else perl.G_SCALAR

        cdef int count
        cdef int i
        perl.dSP
        perl.ENTER
        perl.SAVETMPS 

        perl.PUSHMARK(perl.SP)
        if self._self:
            perl.XPUSHs(self._self)
        for arg in self._args:
            perl.mXPUSHs(_new_sv_from_object(arg))
        for k,v in self._kwds.items():
            perl.mXPUSHs(_new_sv_from_object(k))
            perl.mXPUSHs(_new_sv_from_object(v))
        perl.PUTBACK
        try:
            if self._self:
                method = str(self._method).encode()
                count = perl.call_method(method, perl.G_EVAL|flag)
            elif self._name:
                name = str(self._name).encode()
                count = perl.call_pv(name, perl.G_EVAL|flag)
            elif self._sv:
                count = perl.call_sv(self._sv, perl.G_EVAL|flag)
            else:
                raise AssertionError()
            perl.SPAGAIN
            ret = [_sv_new(perl.POPs, self._interpreter) for i in range(count)]
            ret.reverse()
            if perl.SvTRUE(perl.ERRSV):
                raise RuntimeError(perl.SvPVutf8_nolen(perl.ERRSV).decode())
            if list_context:
                return tuple(ret)
            else:
                return ret[0]
        finally:
            perl.PUTBACK
            perl.FREETMPS
            perl.LEAVE

    def __iter__(self):
        for r in self.result(True):
            yield r

    def strings(self):
        return tuple(str(e) for e in self)

    def ints(self):
        return tuple(int(e) for e in self)

    def __int__(self):
        return int(self.result(False))

    def __str__(self):
        return str(self.result(False))

    def __repr__(self):
        return repr(self.result(False))

    def __dealloc__(self):
        if not self._evaluated:
            self.result(False)
        perl.SvREFCNT_dec(self._self)
        perl.SvREFCNT_dec(self._sv)

    def __add__(self, other):
        return int(self) + other
import sys,os
PERL_SYS_INIT3(sys.argv, os.environ)

# we need to reload the perl libary with RTLD_GLOBAL, because many compiled CPAN
# modules assume that those symbols are available. Python does not import the
# library's symbols into a global namespace
cdef void* handle=dlfcn.dlopen("libperl.so",dlfcn.RTLD_LAZY|dlfcn.RTLD_GLOBAL)
if(not handle):
    raise RuntimeError("Could not load perl: %s" % dlfcn.dlerror())
