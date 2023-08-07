# -*- Python -*-

import os
import platform
import re
import subprocess
import tempfile

import lit.formats
import lit.util

config.name = "LDC Linter Plugin"

config.suffixes = [ ".d" ]
config.excludes = []
config.test_format = lit.formats.ShTest(execute_external=False)


config.substitutions.append(("%PATH%", config.environment["PATH"]))
