#!/bin/sh
#
# Fastrpc  RPC using XML and binary protocol.
# Copyright (C) 2004  Seznam.cz, a.s.
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
# Naskove 1, Praha 5, 15000, Czech Republic
# http://www.seznam.cz, mailto:fastrpc@firma.seznam.cz
#
#
# $Id: make.sh,v 1.3 2006-02-24 15:53:55 vasek Exp $
#
# DESCRIPTION
# Packager for Fastrpc library.
#
# AUTHORS
# Miroslav Talasek <miroslav.talasek@firma.seznam.cz>
#
# HISTORY
# 2005-03-08  (miro)
#             Created.
#


########################################################################
# Command line options.                                                #
########################################################################
while [ "$#" != "0" ]; do
    case "$1" in
        --help)
            echo "Usage: make.sh [--debug] [--help]."
            echo "    --debug              log every command to stderr (set -x)"
            echo "    --help               show this help"
            echo ""
            echo "    To change package's version please edit file configure.in in upper"
            echo "    directory. Control file is generated by expanding <tags> in the"
            echo "    libfastrpc[-dev].control file."
            echo ""
            echo "    You can also create libtfastrpc[-dev].postinst, libfastrpc[-dev].preinst,"
            echo "    libfastrpc[-dev].conffiles, libfastrpc[-dev].prerm and libfastrpc[-dev].postrm files"
            echo "    that would be used as postinst, preinst, conffiles, prerm and postrm"
            echo "    files in the package."
            exit 0
        ;;

        --debug)
            set -x
            DEBUG="debug"
        ;;

        --make-binary)
            MODE="binary"
        ;;
            
        --make-dev)
            MODE="dev"
        ;;

        --skip-build)
            SKIP_BUILD="yes"
        ;;
            
        --skip-install)
            SKIP_BUILD="yes"
            SKIP_INSTALL="yes"
        ;;

        *)
            echo "Unknown option '$1', try make.sh --help." >> /dev/stderr
            exit 1
        ;;
    esac
    shift
done

if test "$DEBUG" = "debug"; then
    set -x
fi

function make_dirs {
    # Compose package name
    dash=`echo ${PROJECT_NAME} | grep -e'-'`
    if test "${dash}" = ""; then
        # libfastrpc
        PACKAGE_NAME=${PROJECT_NAME}${LIBRARY_VERSION}
    else
        # libfastrpc-dev
        name=`echo ${PROJECT_NAME} | cut -f1 -d'-'`
        suff=`echo ${PROJECT_NAME} | cut -f2- -d'-'`
        PACKAGE_NAME=${name}${LIBRARY_VERSION}-${suff}
    fi

    # Create package destination directory.
    PACKAGE_DIR=pkg
    mkdir -p ${PACKAGE_DIR}

    # Create build directory (force it to be clean).
    BUILD_DIR=build
    mkdir -p ${BUILD_DIR}
    rm -Rf ${BUILD_DIR}

    # Create directories and set their attributes.
    DEBIAN_BASE=${BUILD_DIR}/${PACKAGE_NAME}
    CONTROL_DIR=${DEBIAN_BASE}/DEBIAN
    mkdir -p ${CONTROL_DIR}
    chmod 0755 ${CONTROL_DIR}
}

function replace_vars {
    # Process control file -- all <tags> will be replaced with
    # appropriate data.
    sed -e "s/@VERSION@/${VERSION}/" \
        -e "s/@PACKAGE@/${PACKAGE_NAME}/" \
        -e "s/@MAINTAINER@/${MAINTAINER}/" \
        -e "s/@ARCHITECTURE@/$(dpkg --print-architecture)/" \
        -e "s/@SIZE@/${SIZE}/" \
        -e "s/@EXTRA_DEPEND@/${EXTRA_DEPEND}/" \
        -e "s/@SO_VERSION@/${LIBRARY_VERSION}/" \
        $1 > $2 || exit -1
}

function build_package {
    ########################################################################
    # Package housekeeping                                                 #
    ########################################################################

    case $(< /etc/debian_version) in
        "3.0")
            # woody
            DISTRIB=".woody"
            ;;

        "3.1")
            # sarge
            DISTRIB=".sarge"
            ;;

        *)
            # unknown
            DISTRIB=""
            ;;
    esac

    # Copy extra package files -- runnable
    for FILE in postinst preinst prerm postrm; do
        if test -f ${PROJECT_NAME}.${FILE}${DISTRIB}; then
            cp ${PROJECT_NAME}.${FILE}${DISTRIB} ${CONTROL_DIR}/${FILE}
            chmod 755 ${CONTROL_DIR}/${FILE}
        fi
    done

    # Copy unrunnable files
    test -f ${PROJECT_NAME}.conffiles${DISTRIB} && \
        cp ${PROJECT_NAME}.conffiles${DISTRIB} ${CONTROL_DIR}/conffiles

    # Remove any lost CVS entries in the package tree.
    find ${DEBIAN_BASE} -path "*CVS*" -exec rm -Rf '{}' \; || exit 1

    # Compute package's size.
    SIZEDU=$(du -sk ${DEBIAN_BASE} | awk '{ print $1}') || exit 1
    SIZEDIR=$(find ${DEBIAN_BASE} -type d | wc | awk '{print $1}') || exit 1
    SIZE=$[ $SIZEDU - $SIZEDIR ] || exit 1
    
    VERSION=$(< ../version)

    replace_vars ${PROJECT_NAME}.control${DISTRIB} ${CONTROL_DIR}/control || exit 1

    test -f ${PROJECT_NAME}.shlibs${DISTRIB} && \
        replace_vars ${PROJECT_NAME}.shlibs${DISTRIB} ${CONTROL_DIR}/shlibs

    # Create and rename the package.
    dpkg --build ${DEBIAN_BASE} ${PACKAGE_DIR}/${PACKAGE_NAME}.deb || exit 1
    dpkg-name -o ${PACKAGE_DIR}/${PACKAGE_NAME}.deb || exit 1

    # Get rid of temporary build directory.
    rm -r ${BUILD_DIR}
}

# determine operation
if test "${MODE}" = "binary"; then
    # we are making binarty package
    # Make all directories
    make_dirs || exit 1

    ########################################################################
    # Copy all files                                                       #
    ########################################################################

    # lib files
    mkdir -p ${DEBIAN_BASE}/usr/lib
    cp -vd ${INSTALL_DIR}/usr/lib/*.so.* ${DEBIAN_BASE}/usr/lib || exit 1

#    # info files
#    mkdir -p ${DEBIAN_BASE}/usr/share/info
#    cp -vR ${INSTALL_DIR}/usr/share/info ${DEBIAN_BASE}/usr/share || exit 1

    # Build the package
    build_package
    exit $?
elif test "${MODE}" = "dev"; then
    BINARY_PROJECT_NAME=${PROJECT_NAME}

    # we are making dev package
    PROJECT_NAME=${PROJECT_NAME}-dev

    # Make all directories
    make_dirs || exit 1

    ########################################################################
    # Copy all files                                                       #
    ########################################################################

    # headers
    mkdir -p ${DEBIAN_BASE}/usr/include
    cp -v ${INSTALL_DIR}/usr/include/*.h ${DEBIAN_BASE}/usr/include || exit 1

    # lib files
    mkdir -p ${DEBIAN_BASE}/usr/lib
    cp -v ${INSTALL_DIR}/usr/lib/*.a ${DEBIAN_BASE}/usr/lib || exit 1
    cp -v ${INSTALL_DIR}/usr/lib/*.la ${DEBIAN_BASE}/usr/lib || exit 1
    cp -vd ${INSTALL_DIR}/usr/lib/*.so ${DEBIAN_BASE}/usr/lib || exit 1
    
    # Compose extra dependencies: we must depend on fastrpc library with
    # exactly same version.
    VERSION=$(< ../version)
    EXTRA_DEPEND="${BINARY_PROJECT_NAME}${LIBRARY_VERSION} (= ${VERSION})"

    # Build the package
    build_package
    exit $?
fi

# Installation

########################################################################
# Build and install.                                                   #
########################################################################

# project name
PROJECT_NAME="libfastrpc"

# Maintainer of this module
MAINTAINER="Miroslav Talasek <miroslav.talasek@firma.seznam.cz>"

# Create install directory.
INSTALL_DIR=$(pwd)/"install"
rm -Rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}

# Build.
if test -z "${SKIP_BUILD}"; then
    (
        # Try to determine number of processors => we will tell make to run
        # same number of jobs in parallel.
        # This is appropriate only for linux. If you know how to determine number
        # of processor on your platform do no hassitate :-)
        PROCESSORS=$((cat /proc/cpuinfo || echo processor) | grep ^processor | wc -l) \
                    || exit 1

        # go to the project root
        cd ..
    
        # configure sources -- we want to instal under /usr
        # info goes to share dir
        ./configure --prefix=/usr --infodir=/usr/share/info || exit 1
        # clean any previously created files
        make clean  || exit 1
        # make libfastrpc
        make -j ${PROCESSORS} all  || exit 1
    )
fi

# Install to temporary directory.
if test -z "${SKIP_INSTALL}"; then
    (
        cd ..
        # install libfastrpcOC to the install-dir
        make DESTDIR=${INSTALL_DIR} install || exit 1
    )
fi

########################################################################
# Call packagers to create both binary an dev packages.                #
########################################################################

# Variables INSTALL_DIR and LIBRARY_VERSION must be exported for propper
# operation of packages.

# Determine library version -- we generate libfastrpc<LIBRARY_VERSION>
# and libfastrpc<LIBRARY_VERSION>-dev packages.
export LIBRARY_VERSION=$(sed -n -e 's/current=\(.*\)/\1/p' \
                         ${INSTALL_DIR}/usr/lib/libfastrpc.la) || exit 1

export PROJECT_NAME
export INSTALL_DIR
export DEBUG
export MAINTAINER

# Create binary package (must be run under fakeroot).
fakeroot ./make.sh --make-binary || exit 1

# Create dev package (must be run under fakeroot).
fakeroot ./make.sh --make-dev || exit 1

# Get rid of residuals
rm -Rf ${INSTALL_DIR}