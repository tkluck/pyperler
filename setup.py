from distutils.core import setup
from distutils.sysconfig import get_config_var
from distutils.extension import Extension
from Cython.Distutils import build_ext
from subprocess import check_output

import os
perl = os.environ.get('PERL', 'perl')

cflags = check_output([perl, "-MExtUtils::Embed", "-e", "ccopts"], universal_newlines=True).split()
ldflags = check_output([perl, "-MExtUtils::Embed", "-e", "ldopts"], universal_newlines=True).split()
setup(
    cmdclass = {'build_ext': build_ext},
    ext_modules = [Extension("pyperler", "perl.pxd pyperler.pyx pyperler_extra.c dlfcn.pxd".split(),
            library_dirs=[get_config_var('LIBDIR')],
            extra_compile_args=cflags,
            extra_link_args=ldflags,
        )]
)
