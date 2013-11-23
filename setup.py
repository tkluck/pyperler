from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext
from subprocess import check_output

import os
perl = os.environ.get('PERL', 'perl')

cflags = check_output([perl, "-MExtUtils::Embed", "-e", "ccopts"]).split()
ldflags = check_output([perl, "-MExtUtils::Embed", "-e", "ldopts"]).split()
setup(
    cmdclass = {'build_ext': build_ext},
    ext_modules = [Extension("pyperler", "perl.pxd pyperler.pyx pyperler_extra.c dlfcn.pxd".split(),
            extra_compile_args=cflags,
            extra_link_args=ldflags,
        )]
)
