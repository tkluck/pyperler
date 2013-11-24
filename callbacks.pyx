cdef void call_object(perl.CV* p1, perl.CV* p2):
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items < 1:
        perl.croak("Cannot use call_object without a Python object")
        perl.XSRETURN(0)

    try:
        args = [_sv_new(perl.stack[i], None) for i in xrange(1, perl.items)]
        obj_ptr = <void*>perl.SvIVX(perl.SvRV(perl.stack[0]))
        if obj_ptr:
            obj = <object>obj_ptr
            ret = obj(*args)
            perl.stack[0] = perl.sv_2mortal(_new_sv_from_object(ret))
            perl.XSRETURN(1)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        perl.croak(value.message)


cdef void object_to_str(perl.CV* p1, perl.CV* p2):
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items < 1:
        perl.croak("Should call object_to_str with at least an object argument")
        perl.XSRETURN(0)

    try:
        obj_ptr = <void*>perl.SvIVX(perl.SvRV(perl.stack[0]))
        if obj_ptr:
            obj = <object>obj_ptr
            ret = str(obj)
            perl.stack[0] = perl.sv_2mortal(_new_sv_from_object(ret))
            perl.XSRETURN(1)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        perl.croak(value.message)

cdef void object_to_bool(perl.CV* p1, perl.CV* p2):
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items < 1:
        perl.croak("Should pass at least an object to object_to_bool")
        perl.XSRETURN(0)

    try:
        obj_ptr = <void*>perl.SvIVX(perl.SvRV(perl.stack[0]))
        if obj_ptr:
            obj = <object>obj_ptr
            ret = bool(obj)
            perl.stack[0] = perl.sv_2mortal(_new_sv_from_object(ret))
            perl.XSRETURN(1)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        perl.croak(value.message)

cdef void object_get_item(perl.CV* p1, perl.CV* p2):
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items != 2:
        perl.croak("Should call object_get_item with two arguments")
        perl.XSRETURN(0)

    try:
        args = [_sv_new(perl.stack[i], None) for i in xrange(1, perl.items)]
        obj_ptr = <void*>perl.SvIVX(perl.SvRV(perl.stack[0]))
        if obj_ptr:
            obj = <object>obj_ptr
            ret = obj[args[0]]
            perl.stack[0] = perl.sv_2mortal(_new_sv_from_object(ret))
            perl.XSRETURN(1)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        perl.croak(value.message)


cdef void object_set_item(perl.CV* p1, perl.CV* p2):
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items != 3:
        perl.croak("Should call object_set_item with three arguments")
        perl.XSRETURN(0)

    try:
        args = [_sv_new(perl.stack[i], None) for i in xrange(1, perl.items)]
        obj_ptr = <void*>perl.SvIVX(perl.SvRV(perl.stack[0]))
        if obj_ptr:
            obj = <object>obj_ptr
            obj[args[0]] = args[1]
            ret = None
            perl.stack[0] = perl.sv_2mortal(_new_sv_from_object(ret))
            perl.XSRETURN(1)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        perl.croak(value.message)

cdef void object_del_item(perl.CV* p1, perl.CV* p2):
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items != 2:
        perl.croak("Should call object_del_item with two arguments")
        perl.XSRETURN(0)

    try:
        args = [_sv_new(perl.stack[i], None) for i in xrange(1, perl.items)]
        obj_ptr = <void*>perl.SvIVX(perl.SvRV(perl.stack[0]))
        if obj_ptr:
            obj = <object>obj_ptr
            del obj[args[0]]
            ret = None
            perl.stack[0] = perl.sv_2mortal(_new_sv_from_object(ret))
            perl.XSRETURN(1)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        perl.croak(value.message)


cdef void object_length(perl.CV* p1, perl.CV* p2):
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items != 1:
        perl.croak("Should call object_length with a single object argument")
        perl.XSRETURN(0)

    try:
        obj_ptr = <void*>perl.SvIVX(perl.SvRV(perl.stack[0]))
        if obj_ptr:
            obj = <object>obj_ptr
            ret = len(obj)
            perl.stack[0] = perl.sv_2mortal(_new_sv_from_object(ret))
            perl.XSRETURN(1)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        perl.croak(value.message)

cdef void object_is_mapping(perl.CV* p1, perl.CV* p2):
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items != 1:
        perl.croak("Should call object_to_str with single object argument")
        perl.XSRETURN(0)

    try:
        obj_ptr = <void*>perl.SvIVX(perl.SvRV(perl.stack[0]))
        if obj_ptr:
            obj = <object>obj_ptr
            ret = hasattr(type(obj), '__getitem__')
            perl.stack[0] = perl.sv_2mortal(_new_sv_from_object(ret))
            perl.XSRETURN(1)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        perl.croak(value.message)

cdef void dummy(perl.CV* p1, perl.CV* p2):
    return

