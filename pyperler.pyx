r"""
>>> import pyperler
>>> i = pyperler.Interpreter()

Accessing scalar variables:
>>> i("$a = 2 + 2;")
>>> i.Sa
'4'
>>> i['$a']
'4'
>>> list(range(i.Sa))
[0, 1, 2, 3]
>>> i.Sa = 5
>>> list(range(i.Sa))
[0, 1, 2, 3, 4]
>>> i['undef']
None

Evaluating list expressions in array context:
>>> i["qw / a b c d e /"].strings()
['a', 'b', 'c', 'd', 'e']

With perl's weak typing, any non-number string has the integer value 0:
>>> i["qw / a b c d e /"].ints()
[0, 0, 0, 0, 0]

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

Accessing array values:
>>> i("@d = (10 .. 20)")
>>> i.Ad.ints()
[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
>>> list(i.Ad)[2]
'12'
>>> i.Ad[0] = 9
>>> int(i['$d[0]'])
9
>>> i['@d[0..2]'].ints()
[9, 11, 12]
>>> i.Ad.ints()
[9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]

Assigning iterables to arrays:
>>> i.Ad = (10 for _ in range(5))
>>> i.Ad.ints()
[10, 10, 10, 10, 10]
>>> i.Aletters = "nohtyP ni lreP"
>>> i('@letters = reverse @letters')
>>> list(i.Aletters)
['P', 'e', 'r', 'l', ' ', 'i', 'n', ' ', 'P', 'y', 't', 'h', 'o', 'n']

Accessing hash values:
>>> i("%b = (greece => 'Aristotle', germany => 'Hegel');")
>>> i.Pb.dict()
{'germany': 'Hegel', 'greece': 'Aristotle'}
>>> i.Pb['greece']
'Aristotle'
>>> i.Pb['germany'] = 'Kant'
>>> i('$c = $b{germany}')
>>> i.Sc
'Kant'
>>> i.Pparrot = {'dead': True}
>>> i["$parrot{dead}"]
'1'

Accessing objects (see below for why we assign to _):
>>> i("unshift @INC, './perllib'")
>>> i("use Car; $car = Car->new")
>>> _ = i.Scar.set_brand("Toyota")
>>> _ = i.Scar.drive(20)
>>> del _
>>> i["$car->distance"]
'20'
>>> int(i.Scar.distance())
20

About the assignments to _: If we do not use the return value, then
we do not know whether the method should be called in scalar or in array
context. For that reason, we defer evaluation until the return value is actually
used.

This works as follows. The method call `i.Scar.set_brand("Toyota")` returns a
`pyperler.LazyEvaluation` object. You can use this object in several ways: if
you cast it to an int or str, or use its representation, it will be called in
scalar context. If you iterate over it, or call one of the strings() or ints()
methods, it will be called in array context. If you don't use it at all, it
will be called upon garbage collection of the object. Because CPython uses a
reference counting system, this garbage collection is always immediate if you
do not use the return value. This means that 'normal' Python code would not
have to use this trick. In the doctesting framework, however, or in IPython,
references are kept to previous return values. Our trick with _ makes sure that
the returned objects are garbage collected immediately.

Alternatively, we can let the methods be called as a result of the `repr` call:
>>> i.Scar.drive(20)
None

Verify that this makes the intended change to the object:
>>> i["$car->distance"]
'40'
>>> int(i.Scar.distance())
40

Nested structures:
>>> i("$a = { dictionary => { a => 65, b => 66 }, array => [ 4, 5, 6] }")
>>> i.Sa['dictionary']['a']
'65'
>>> i.Sa['array'][1]
'5'

Assigning non-string iterables to a nested element will create an arrayref:
>>> i.Sa['array'] = xrange(2,5)
>>> i["@{ $a->{array} }"].ints()
[2, 3, 4]

Similarly, assiging a dict to a nested element will create a hashref:
>>> i.Sa['dictionary'] = {'c': 67, 'd': 68}
>>> int(i['$a->{dictionary}->{c}'])
67
>>> i['keys %{ $a->{dictionary} } '].strings()
['c', 'd']

"""
from libc.stdlib cimport malloc, free
from cpython.string cimport PyString_AsString
cimport perl

cpdef PERL_SYS_INIT3(argv, env):
    cdef int argc
    cdef char** cargv
    cdef char** cenv
    perl.PERL_SYS_INIT3(&argc, &cargv, &cenv)

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
            string_buf[i] = PyString_AsString(argv[i])
        perl.perl_parse(perl.my_perl, NULL, len(argv), string_buf, NULL)
        free(string_buf)

    def run(self):
        perl.perl_run(perl.my_perl)

    def eval_pv(self, code, croak_on_error):
        perl.eval_pv(code, croak_on_error)

class Interpreter(object):
    def __init__(self):
        self._interpreter = _PerlInterpreter()
        self._interpreter.parse(["","-e","0"])
        self._interpreter.run()

    def __call__(self, code):
        self._interpreter.eval_pv(code, True)

    def __getitem__(self, expression):
        return LazyExpression(self, expression)

    def __getattribute__(self, name):
        initial = name[0].upper()
        if initial in 'SD':
            return LazyVariable(self, '$', name[1:])
        elif initial == 'A':
            return LazyVariable(self, '@', name[1:])
        elif initial in 'PH': 
            return LazyVariable(self, '%', name[1:])
        else:
            return object.__getattribute__(self, name)

    def __setattr__(self, name, value):
        initial = name[0].upper()
        name = name[1:]
        cdef perl.SV *sv
        cdef perl.AV *array_value
        cdef perl.HV *hash_value
        if initial in 'SD':
            sv = perl.get_sv(name, perl.GV_ADD)
            _assign_sv(sv, value)
        elif initial == 'A':
            array_value = perl.get_av(name, perl.GV_ADD)
            perl.av_clear(array_value)
            for element in value:
                perl.av_push(array_value, _new_sv_from_object(element))
        elif initial in 'PH':
            hash_value = perl.get_hv(name, perl.GV_ADD)
            perl.hv_clear(hash_value)
            for k, v in value.iteritems():
                perl.hv_store(hash_value, k, len(k), _new_sv_from_object(v), 0)
        else:
            return object.__setattr__(self, initial + name, value)

cdef class LazyExpression:
    cdef object _interpreter
    cdef object _expression
    cdef bint _evaluated
    def __init__(self, interpreter, expression):
        self._interpreter = interpreter
        self._expression = expression

    cdef perl.SV* _expression_sv(self):
        return perl.newSVpvn_utf8(self._expression, len(self._expression), True)
        
    def strings(self):
        if self._evaluated: raise RuntimeError("Cannot use lazy expression multiple times")
        self._evaluated = True

        perl.dSP
        cdef int count = perl.eval_sv(self._expression_sv(), perl.G_ARRAY)
        perl.SPAGAIN
        ret = [perl.POPp for _ in range(count)]
        perl.PUTBACK
        ret.reverse()
        return ret

    def ints(self):
        if self._evaluated: raise RuntimeError("Cannot use lazy expression multiple times")
        self._evaluated = True

        perl.dSP
        perl.ENTER
        perl.SAVETMPS
        cdef int count = perl.eval_sv(self._expression_sv(), perl.G_ARRAY)
        perl.SPAGAIN
        ret = [perl.POPl for _ in range(count)]
        perl.PUTBACK
        
        perl.FREETMPS
        perl.LEAVE
        ret.reverse()
        return ret

    def __iter__(self):
        if self._evaluated: raise RuntimeError("Cannot use lazy expression multiple times")
        self._evaluated = True

        perl.dSP
        cdef int count = perl.eval_sv(self._expression_sv(), perl.G_ARRAY)
        perl.SPAGAIN
        ret = [_sv_new(perl.POPs) for _ in range(count)]
        perl.PUTBACK
        return reversed(ret)

    def __str__(self):
        if self._evaluated: raise RuntimeError("Cannot use lazy expression multiple times")
        self._evaluated = True

        cdef perl.SV *sv = perl.eval_pv(self._expression, True)
        return perl.SvPVutf8_nolen(sv)

    def __int__(self):
        if self._evaluated: raise RuntimeError("Cannot use lazy expression multiple times")
        self._evaluated = True

        perl.dSP
        cdef int count = perl.eval_sv(self._expression_sv(), perl.G_SCALAR)
        perl.SPAGAIN
        ret = perl.POPl
        perl.PUTBACK
        return ret

    def __repr__(self):
        if self._evaluated: raise RuntimeError("Cannot use lazy expression multiple times")
        self._evaluated = True

        cdef perl.SV *sv = perl.eval_pv(self._expression, True)
        if perl.SvOK(sv):
            return "'" + perl.SvPVutf8_nolen(sv) + "'"
        else:
            return "None"
        
    def __cmp__(left, right):
        pass

    def __nonzero__(left):
        pass

cdef class LazyVariable(LazyExpression):
    cdef object _type
    cdef object _name
    def __init__(self, interpreter, type, name):
        self._type = type
        self._name = name
        LazyExpression.__init__(self, interpreter, type + name)

    def __getitem__(self, key):
        cdef perl.SV** scalar_value
        cdef perl.AV* array_value
        cdef perl.HV* hash_value
        if self._type == '$':
            return _sv_new(perl.get_sv(self._name, 0))[key]
        elif self._type == '@':
            array_value = perl.get_av(self._name, 0)
            scalar_value = perl.av_fetch(array_value, key, False)
            return _sv_new(scalar_value[0])
        elif self._type == '%':
            hash_value = perl.get_hv(self._name, 0)
            scalar_value = perl.hv_fetch(hash_value, key, len(key), False)
            return _sv_new(scalar_value[0])
        
    def __setitem__(self, key, value):
        cdef perl.HV* hash_value
        cdef perl.AV* array_value
        cdef perl.SV** scalar_value
        if self._type == '$':
            _sv_new(perl.get_sv(self._name, 0))[key] = value
        elif self._type in '@%':
            if self._type == '@':
                array_value = perl.get_av(self._name, 0)
                scalar_value = perl.av_fetch(array_value, key, True)
            else:
                hash_value = perl.get_hv(self._name, 0)
                scalar_value = perl.hv_fetch(hash_value, key, len(key), True)
            if scalar_value:
                scalar_value[0] = _new_sv_from_object(value)
            else:
                raise NameError("variable %s does not have ....")
        else:
            raise TypeError("variable %s cannot be indexed" % self._name)

    def __iter__(self):
        cdef perl.SV** scalar_value
        cdef perl.AV* array_value
        cdef perl.HV* hash_value
        cdef int i
        cdef int count
        cdef char *key
        cdef int retlen
        cdef perl.SV *sv

        if self._type == '$':
            yield self
        elif self._type == '@':
            array_value = perl.get_av(self._name, 0)
            count = perl.av_len(array_value)
            for i in range(count+1):
                scalar_value = perl.av_fetch(array_value, i, False)
                yield _sv_new(scalar_value[0])
        elif self._type == '%':
            hash_value = perl.get_hv(self._name, 0)
            count = perl.hv_iterinit(hash_value)
            for i in range(count):
                sv = perl.hv_iternextsv(hash_value, &key, &retlen)
                yield key, _sv_new(sv)

    def dict(self):
        if self._type == '%':
            return {key: value for key, value in self}
        else:
            raise TypeError("'%s' is not a hash" % self._name)

    def keys(self):
        return self.dict().keys()

    def values(self):
        return self.dict().values()

    def __getattr__(self, name):
        if self._type == '$':
            ret = BoundMethod()
            ret._sv = perl.SvREFCNT_inc(perl.get_sv(self._name, 0))
            ret._method = name
            return ret
        else:
            raise AttributeError()

    def __len__(self):
        cdef perl.AV* array_value
        if self._type == '@':
            array_value = perl.get_av(self._name, 0)
            if array_value:
                return perl.av_len(array_value) + 1
            else:
                raise RuntimeError()
        else:
            raise TypeError("'%s' has no length" % self._name)
            

cdef _sv_new(perl.SV *sv):
    ret = ScalarValue()
    ret._sv = perl.SvREFCNT_inc(sv)
    return ret

def iter_or_none(value):
    try:
        return iter(value)
    except TypeError:
        return None

cdef perl.SV *_new_sv_from_object(object value):
    cdef perl.AV* array_value
    cdef perl.HV* hash_value
    it = iter_or_none(value)
    if isinstance(value, int):
        return perl.newSViv(value)
    elif isinstance(value, str):
        value = (value)
        return perl.newSVpvn_utf8(value, len(value), True)
    elif isinstance(value, dict):
        hash_value = perl.newHV()
        for k, v in value.iteritems():
            k = str(k)
            perl.hv_store(hash_value, k, len(k), _new_sv_from_object(v), 0)
        return perl.newRV_noinc(<perl.SV*>hash_value)
    elif it: 
        array_value = perl.newAV()
        for i in it:
            perl.av_push(array_value, _new_sv_from_object(i))
        return perl.newRV_noinc(<perl.SV*>array_value)
    else:
        value = str(value)
        return perl.newSVpvn_utf8(value, len(value), True)

cdef _assign_sv(perl.SV *sv, object value):
    if isinstance(value, int):
        perl.SvIV_set(sv, value)
    elif isinstance(value, str):
        perl.SvPV_set(sv, value)
    elif isinstance(value, list):
        raise NotImplementedError()

cdef class ScalarValue:
    cdef perl.SV *_sv

    def __dealloc(self):
        perl.SvREFCNT_dec(self._sv)

    def __str__(self):
        return perl.SvPVutf8_nolen(self._sv)

    def __int__(self):
        return perl.SvIV(self._sv)

    def __repr__(self):
        if perl.SvOK(self._sv):
            return "'" + str(self) + "'"
        else:
            return 'None'

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
            return _sv_new(scalar_value[0])
        elif perl.SvTYPE(ref_value) == perl.SVt_PVHV:
            hash_value = <perl.HV*>ref_value
            scalar_value = perl.hv_fetch(hash_value, key, len(key), False)
            return _sv_new(scalar_value[0])
        
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
            perl.hv_store(hash_value, key, len(key), _new_sv_from_object(value), 0)
            #scalar_value = perl.hv_fetch(hash_value, key, len(key), True)
            #if scalar_value:
            #    scalar_value[0] = _new_sv_from_object(value)
            #else:
            #    raise IndexError()

cdef class BoundMethod:
    cdef perl.SV *_sv
    cdef char *_method

    def __call__(self, *args, **kwds):
        ret = LazyCalledMethod()
        ret._sv = perl.SvREFCNT_inc(self._sv)
        ret._method = self._method
        ret._args = args
        ret._kwds = kwds
        return ret
    
    def __dealloc__(self):
        perl.SvREFCNT_dec(self._sv)

cdef class LazyCalledMethod:
    cdef perl.SV *_sv
    cdef char *_method
    cdef object _args
    cdef object _kwds
    cdef bint _evaluated

    def __iter__(self):
        if self._evaluated: raise RuntimeError("Cannot use lazy expression multiple times")
        self._evaluated = True

        cdef int count
        cdef int i
        perl.dSP
        perl.ENTER
        perl.SAVETMPS 

        perl.PUSHMARK(perl.SP)
        perl.XPUSHs(self._sv)
        for arg in self._args:
            perl.mXPUSHs(_new_sv_from_object(arg))
        for k,v in self._kwds.iteritems():
            perl.mXPUSHs(_new_sv_from_object(k))
            perl.mXPUSHs(_new_sv_from_object(v))
        perl.PUTBACK
        count = perl.call_method(self._method, perl.G_ARRAY)
        perl.SPAGAIN
        ret = [_sv_new(perl.POPs) for i in range(count)]
        perl.PUTBACK
        perl.FREETMPS
        perl.LEAVE
        for r in ret:
            yield r

    def __int__(self):
        return int(self._scalar_value())

    def _scalar_value(self):
        if self._evaluated: raise RuntimeError("Cannot use lazy expression multiple times")
        self._evaluated = True

        cdef int count
        cdef int i
        cdef perl.SV* ret_sv
        perl.dSP
        perl.ENTER
        perl.SAVETMPS 

        perl.PUSHMARK(perl.SP)
        perl.XPUSHs(self._sv)
        for arg in self._args:
            perl.mXPUSHs(_new_sv_from_object(arg))
        for k,v in self._kwds.iteritems():
            perl.mXPUSHs(_new_sv_from_object(k))
            perl.mXPUSHs(_new_sv_from_object(v))
        perl.PUTBACK
        count = perl.call_method(self._method, perl.G_SCALAR)
        perl.SPAGAIN
        try:
            if count == 1:
                ret_sv = perl.POPs
                if ret_sv:
                    return _sv_new(ret_sv)
                else:
                    raise RuntimeError()
            else:
                raise RuntimeError()
        finally:
            perl.PUTBACK

            perl.FREETMPS
            perl.LEAVE

    def __str__(self):
        return str(self._scalar_value())

    def __repr__(self):
        return repr(self._scalar_value())

    def __dealloc__(self):
        if not self._evaluated:
            perl.dSP
            perl.ENTER
            perl.SAVETMPS 

            perl.PUSHMARK(perl.SP)
            perl.XPUSHs(self._sv)
            for arg in self._args:
                perl.mXPUSHs(_new_sv_from_object(arg))
            for k,v in self._kwds.iteritems():
                perl.mXPUSHs(_new_sv_from_object(k))
                perl.mXPUSHs(_new_sv_from_object(v))
            perl.PUTBACK
            perl.call_method(self._method, perl.G_SCALAR|perl.G_DISCARD)
            perl.SPAGAIN

            perl.FREETMPS
            perl.LEAVE
        perl.SvREFCNT_dec(self._sv)

    def __add__(self, other):
        return int(self) + other


import sys,os
PERL_SYS_INIT3(sys.argv, os.environ)
