# callbacks.pyx
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

cdef void call_object(perl.CV* p1, perl.CV* p2) with gil:
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items < 1:
        perl.croak("Cannot use call_object without a Python object")
        perl.XSRETURN(0)

    try:
        args = [_sv_to_python(perl.stack[i], None) for i in xrange(1, perl.items)]
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
        if hasattr(value, 'message'):
            perl.croak(value.message)
        else:
            perl.croak("Unhandled exception in call_object")


cdef void object_to_str(perl.CV* p1, perl.CV* p2) with gil:
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
        if hasattr(value, 'message'):
            perl.croak(value.message)
        else:
            perl.croak("Unhandled exception in object_to_str")

cdef void object_to_bool(perl.CV* p1, perl.CV* p2) with gil:
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
        if hasattr(value, 'message'):
            perl.croak(value.message)
        else:
            perl.croak("Unhandled exception in object_to_bool")

cdef void object_get_item(perl.CV* p1, perl.CV* p2) with gil:
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items != 2:
        perl.croak("Should call object_get_item with two arguments")
        perl.XSRETURN(0)

    try:
        args = [_sv_to_python(perl.SvREFCNT_inc(perl.stack[i]), None) for i in xrange(1, perl.items)]
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
        if hasattr(value, 'message'):
            perl.croak(value.message)
        else:
            perl.croak("Unhandled exception in object_get_item")


cdef void object_set_item(perl.CV* p1, perl.CV* p2) with gil:
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items != 3:
        perl.croak("Should call object_set_item with three arguments")
        perl.XSRETURN(0)

    try:
        args = [_sv_to_python(perl.SvREFCNT_inc(perl.stack[i]), None) for i in xrange(1, perl.items)]
        obj_ptr = <void*>perl.SvIVX(perl.SvRV(perl.stack[0]))
        if obj_ptr:
            obj = <object>obj_ptr
            obj[args[0]] = args[1]
            perl.XSRETURN(0)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        perl.croak(value.message)

cdef void object_del_item(perl.CV* p1, perl.CV* p2) with gil:
    perl.dSP
    perl.dMARK
    perl.dAX
    perl.dITEMS

    cdef void* obj_ptr

    if perl.items != 2:
        perl.croak("Should call object_del_item with two arguments")
        perl.XSRETURN(0)

    try:
        args = [_sv_to_python(perl.SvREFCNT_inc(perl.stack[i]), None) for i in xrange(1, perl.items)]
        obj_ptr = <void*>perl.SvIVX(perl.SvRV(perl.stack[0]))
        if obj_ptr:
            obj = <object>obj_ptr
            del obj[args[0]]
            perl.XSRETURN(0)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        if hasattr(value, 'message'):
            perl.croak(value.message)
        else:
            perl.croak("Unhandled exception in object_del_item")


cdef void object_length(perl.CV* p1, perl.CV* p2) with gil:
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
            perl.stack[0] = perl.sv_2mortal(perl.newSViv(len(obj)))
            perl.XSRETURN(1)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        if hasattr(value, 'message'):
            perl.croak(value.message)
        else:
            perl.croak("Unhandled exception in object_length")

cdef void object_is_mapping(perl.CV* p1, perl.CV* p2) with gil:
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
            if hasattr(type(obj), '__getitem__'):
                perl.stack[0] = perl.sv_2mortal(&perl.PL_sv_yes)
            else:
                perl.stack[0] = perl.sv_2mortal(&perl.PL_sv_no)
            perl.XSRETURN(1)
        else:
            raise RuntimeError("Not a python object")
    except:
        exctype, value = sys.exc_info()[:2]
        if hasattr(value, 'message'):
            perl.croak(value.message)
        else:
            perl.croak("Unhandled exception in object_is_mapping")

cdef void dummy(perl.CV* p1, perl.CV* p2):
    return

