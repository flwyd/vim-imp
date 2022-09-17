from __future__ import division, unicode_literals
import re, io, time
import test.support, unittest.mock
from os import path, environ
from test.support import run_unittest, requires, TESTFN
from fruit.tree import apple as a, banana as b, cherry as c, durian as d
