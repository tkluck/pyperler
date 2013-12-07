import pyperler
import doctest
import sys

failure_count, test_count = doctest.testmod(pyperler)
sys.exit(
    1 if failure_count else 0
)
