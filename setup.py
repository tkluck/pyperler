from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext
from subprocess import check_output
cflags = check_output(["perl", "-MExtUtils::Embed", "-e", "ccopts"]).split()
ldflags = check_output(["perl", "-MExtUtils::Embed", "-e", "ldopts"]).split()
setup(
    cmdclass = {'build_ext': build_ext},
    ext_modules = [Extension("pyperler", ["pyperler.pyx", "pyperler_extra.c"],
            extra_compile_args=cflags,
            extra_link_args=ldflags,
        )]
)
