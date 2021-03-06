#!/usr/bin/env python
# FastRPC -- Fast RPC library compatible with XML-RPC
# Copyright (C) 2005-7  Seznam.cz, a.s.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# Seznam.cz, a.s.
# Radlicka 2, Praha 5, 15000, Czech Republic
# http://www.seznam.cz, mailto:fastrpc@firma.seznam.cz
#

# This version is used when packaging.
VERSION          = "1.0.0"

# Maintainer of this module.
MAINTAINER       = "Miroslav Talasek"
MAINTAINER_EMAIL = "miroslav.talasek@firma.seznam.cz"

# Descriptions
DESCRIPTION      = "FastRPC - RPC protocol suport Binary and XML format."
LONG_DESCRIPTION = "FastRPC - RPC protocol suport Binary and XML format.\n"

# You probably don't need to edit anything below this line

from distutils.core import setup, Extension

########################################################################
# Forces g++ instead of gcc on most systems
# credits to eric jones (eric@enthought.com) (found at Google Groups)
import distutils.sysconfig

old_init_posix = distutils.sysconfig._init_posix

def _init_posix():
    old_init_posix()

    if distutils.sysconfig._config_vars["MACHDEP"].startswith("sun"):
        # Sun needs forced gcc/g++ compilation
        distutils.sysconfig._config_vars['CC'] = 'gcc'
        distutils.sysconfig._config_vars['CXX'] = 'g++'
    else:
        # Non-Sun needs linkage with g++
        distutils.sysconfig._config_vars['LDSHARED'] = 'g++ -shared -g -W -Wall -Wno-deprecated'
    #endif

    distutils.sysconfig._config_vars['CFLAGS'] = '-g -W -Wall -Wno-deprecated'
    distutils.sysconfig._config_vars['OPT'] = '-g -W -Wall -Wno-deprecated'
#enddef

distutils.sysconfig._init_posix = _init_posix
########################################################################

from os import environ
import string

# Main core
setup (
    name             = "fastrpc",
    version          = VERSION,
    author           = "Miroslav Talasek",
    author_email     = "miroslav.talasek@firma.seznam.cz",
    maintainer       = MAINTAINER,
    maintainer_email = MAINTAINER_EMAIL,
    description      = DESCRIPTION,
    long_description = LONG_DESCRIPTION,
    ext_modules = [
        Extension ("fastrpcmodule", ["fastrpcmodule.cc", "pythonserver.cc",
                                     "pyerrors.cc", "pythonbuilder.cc",
                                     "pythonfeeder.cc"],
                   libraries=["fastrpc"]),
        ]
)
