from setuptools import setup, Extension
from distutils.sysconfig import get_config_var
from subprocess import check_output

import os
perl = os.environ.get('PERL', 'perl')

cflags = check_output([perl, "-MExtUtils::Embed", "-e", "ccopts"], universal_newlines=True).split()
ldflags = check_output([perl, "-MExtUtils::Embed", "-e", "ldopts"], universal_newlines=True).split()

setup(
    name = 'pyperler',
    version = '0.2',
    description = 'Run perl code/libraries from within python',
    author = 'Timo Kluck',
    author_email = 'tkluck@infty.nl',
    url='https://github.com/tkluck/pyperler',
    long_description="""
PyPerler allows you to seemlessly interact with Perl code from Python.
""",
    classifiers=[
        "Development Status :: 3 - Alpha",
        "License :: OSI Approved :: GNU General Public License v3 or later (GPLv3+)",
        "Programming Language :: Python",
        "Topic :: Software Development :: Interpreters",
        "Programming Language :: Python :: 2",
        "Programming Language :: Python :: 3",
    ],
    license='GPLv3+',
    keywords='perl, interpreter',
    setup_requires=["cython"],
    ext_modules = [
        Extension("pyperler", "perl.pxd pyperler.pyx pyperler_extra.c dlfcn.pxd".split(),
            library_dirs=[get_config_var('LIBDIR')],
            extra_compile_args=cflags,
            extra_link_args=ldflags,
        ),
    ],
)
