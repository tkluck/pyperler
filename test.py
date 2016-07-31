import pyperler
import doctest
import sys

failure_count_1, test_count_1 = doctest.testmod(pyperler)
failure_count_2, test_count_2 = doctest.testfile("README.md", False)

failure_count = failure_count_1 + failure_count_2
sys.exit(
    1 if failure_count else 0
)
