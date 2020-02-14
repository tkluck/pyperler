import pyperler
import doctest
import sys
import os

__dir__ = os.path.dirname(__file__)

failure_count_1, test_count_1 = doctest.testmod(pyperler)
failure_count_2, test_count_2 = doctest.testfile(os.path.join(__dir__,"README.md"), module_relative=False)

failure_count = failure_count_1 + failure_count_2
sys.exit(
    1 if failure_count else 0
)
