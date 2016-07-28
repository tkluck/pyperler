#
# perl.pxd
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

cdef extern from "pyperler.h":
    PerlInterpreter *my_perl

cdef extern from "EXTERN.h":
    pass

cdef extern from "XSUB.h":
    int dMARK
    int dAX
    int dITEMS
    int items
    void XSRETURN(int count)
    SV **stack

cdef extern from "perl.h":
    ctypedef struct PerlInterpreter:
        int *Imarkstack_ptr
        SV **Istack_base

    ctypedef void *XSINIT_t

    ctypedef struct SV:
        pass

    ctypedef struct AV:
        pass

    ctypedef struct HV:
        pass

    ctypedef struct CV:
        pass

    ctypedef struct RV:
        pass

    ctypedef struct IV:
        pass

    ctypedef struct NV:
        pass

    PerlInterpreter *perl_alloc()
    bint perl_construct(PerlInterpreter *interpreter)
    bint perl_parse(PerlInterpreter *interpreter, XSINIT_t xsinit, int argc, char** argv, char** env)
    bint perl_run(PerlInterpreter *interpreter)

    void croak(char* message)

    SV *eval_pv(char *code, bint croak_on_error) nogil
    int eval_sv(SV *scalar_value, int flags) nogil
    int call_method(char *method_name, int flags) nogil
    int call_pv(char *name, int flags) nogil
    int call_sv(SV* scalar_value, int flags) nogil

    SV *newSV(int len)
    SV *newSVpvn_utf8(char *value, int length, bint utf8)
    SV *newSViv(long value)
    SV *newSVnv(double value)

    SV* newSVrv(SV* rv, char* classname)
    SV* sv_setref_pv(SV *const rv, char* classname, void* pv)
    bint sv_derived_from(SV* scalar_value, char* classname)

    SV* get_sv(char *name, int flags)
    AV* get_av(char *name, int flags)
    HV* get_hv(char *name, int flags)

    IV SvIV(SV* scalar_value)
    IV SvIVX(SV* scalar_value)
    int SvIOK(SV* scalar_value)
    int SvUTF8(SV* scalar_value)
    bint SvIV_set(SV* scalar_value, IV value)
    char *SvPVbyte_nolen(SV* scalar_value)
    char *SvPVbyte(SV* scalar_value, size_t length)
    char *SvPVutf8_nolen(SV* scalar_value)
    char *SvPVutf8(SV* scalar_value, size_t length)
    char *SvPV_nolen(SV* scalar_value)
    char *SvPV(SV* scalar_value, size_t length)
    void SvPV_set(SV* scalar_value, char *value)
    void SvREADONLY(SV* scalar_value)
    void SvSetSV_nosteal(SV* dsv, SV* ssv)
    void SvSetSV(SV* dsv, SV* ssv)

    NV SvNV(SV* scalar_value)
    bint SvNV_set(SV* scalar_value, NV value)
    int SvNOK(SV* scalar_value)
    void SvNOK_on(SV* scalar_value)

    AV *newAV()
    SV **av_fetch(AV* array_value, int key, bint lval)
    int av_len(AV* array_value)
    void av_push(AV* array_value, SV* scalar_value)
    void av_store(AV* array_value, int key, SV* scalar_value)
    void av_clear(AV* array_value)
    int av_top_index(AV* array_value)
    int av_fill(AV* array_value, size_t fill)

    HV *newHV()
    SV **hv_fetch(HV *hash_value, char *key, int strlen, bint lval)
    int hv_iterinit(HV *hash_value)
    SV* hv_iternextsv(HV *hv, char **key, int *retlen)
    void hv_clear(HV* hash_value)
    void hv_store(HV* hash_value, char *key, int strlen, SV* scalar_value, int hash)
    SV* hv_delete(HV* hash_value, char *key, int strlen, int flags)

    int PL_exit_flags
    int PERL_EXIT_DESTRUCT_END
    
    void PERL_SYS_INIT3(int *argc, char*** argv, char*** env)

    int G_VOID
    int G_SCALAR
    int G_ARRAY
    int G_DISCARD
    int G_EVAL

    int GV_ADD

    int dSP
    int SPAGAIN
    int ENTER
    int SAVETMPS
    SV** SP
    int PUSHMARK(SV** SP)
    int PUTBACK
    int FREETMPS
    int LEAVE
    int XSprePUSH

    void mXPUSHi(int value)
    void XPUSHs(SV* scalar_value)
    void mXPUSHs(SV* scalar_value)
    int POPl
    char *POPp
    SV *POPs

    int SvTYPE(SV *scalar_value)
    int SVt_PVAV
    int SVt_PVHV

    bint SvROK(SV *scalar_value)
    SV* SvRV(SV *scalar_value)
    SV* newRV_inc(SV *scalar_value)
    SV* newRV_noinc(SV *scalar_value)
    SV* SvREFCNT_inc(SV *scalar_value)
    SV* SvREFCNT_dec(SV *scalar_value)
    SV* sv_2mortal(SV *scalar_value)

    bint SvOK(SV *scalar_value)

    bint SvTRUE(SV *scalar_value)
    SV *ERRSV

    ctypedef struct MGVTBL:
        int (*svt_get)(SV* sv, MAGIC* mg)
        int (*svt_set)(SV* sv, MAGIC* mg)
        int (*svt_len)(SV* sv, MAGIC* mg)
        int (*svt_clear)(SV* sv, MAGIC* mg)
        int (*svt_free)(SV* sv, MAGIC* mg)

    ctypedef struct MAGIC:
        MGVTBL* mg_virtual

    MAGIC *mg_find(SV *sv, int type)
    void sv_magic(SV* sv, SV* obj, int how, const char* name, int namlen)

    void newXS(char* name, void* fn, char* filename)

    SV PL_sv_undef

    void boot_DynaLoader (CV* cv)

