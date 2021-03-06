#!/bin/bash
#
# Copyright (C) 2004  Seznam.cz, a.s.
#
# $Id: make.sh,v 1.1 2007-10-02 13:42:40 vasek Exp $
#
# DESCRIPTION
# Packager for fastrpc library.
#
# AUTHORS
# Vaclav Blazek <blazek@firma.seznam.cz>
#
# HISTORY
# 2006-02-13  (vasek)
#             Created.
#


########################################################################
# Command line options.                                                #
########################################################################
while [ "$#" != "0" ]; do
    case "$1" in
        --help)
            echo "Usage: make.sh [--debug] [--help]"
            echo "    --skip-build         skip building binaries, install and pack"
            echo "    --skip-install       skip building and installing binaries, just pack"
            echo "    --debug              log every command to stderr (set -x)"
            echo "    --help               show this help"
            echo ""
            echo "    To change package's version please edit file configure.in in upper"
            echo "    directory. Control file is generated by expanding @tags@ in the"
            echo "    libfastrpc[-dev].control file."
            echo ""
            echo "    You can also create libfastrpc[-dev].postinst, libfastrpc[-dev].preinst,"
            echo "    libfastrpc[-dev].conffiles, libfastrpc[-dev].prerm and libfastrpc[-dev].postrm files"
            echo "    that would be used as postinst, preinst, conffiles, prerm and postrm"
            echo "    files in the package."
            exit 0
        ;;

        --debug)
            DEBUG="debug"
        ;;

        --skip-build)
            SKIP_BUILD="yes"
        ;;

        --skip-install)
            SKIP_BUILD="yes"
            SKIP_INSTALL="yes"
        ;;

        # hidden parameter for recursive make.sh calling
        --make-binary)
            MODE="binary"
        ;;

        # hidden parameter for recursive make.sh calling
        --make-dev)
            MODE="dev"
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
    dash=$(echo ${PROJECT_NAME} | grep -- '-')
    if [ "${dash}" = "" ]; then
        # libfastrpc12-0
        PACKAGE_NAME=szn-${PROJECT_NAME}${LIBRARY_VERSION}
        SOL_PACKAGE=SZN-${PROJECT_NAME}${LIBRARY_VERSION}
    else
        # libfastrpc12-0-dev
        name=$(echo ${PROJECT_NAME} | cut -f1 -d'-')
        suff=$(echo ${PROJECT_NAME} | cut -f2- -d'-')
        PACKAGE_NAME=szn-${name}${LIBRARY_VERSION}-${suff}
        SOL_PACKAGE=SZN-${name}${LIBRARY_VERSION}-${suff}
    fi

    # Create package destination directory.
    PACKAGE_DIR=$(pwd)/pkg
    mkdir -p ${PACKAGE_DIR}

    # Create build directory (force it to be clean).
    BUILD_DIR=$(pwd)/build
    mkdir -p ${BUILD_DIR}
    rm -Rf ${BUILD_DIR}

    # Create directories and set their attributes.
    SOLARIS_BASE=${BUILD_DIR}/${PACKAGE_NAME}
    ROOT_DIR=${BUILD_DIR}/${PACKAGE_NAME}/root
    mkdir -p ${ROOT_DIR}
    chmod 0755 ${ROOT_DIR}
}

function replace_vars {
    sed -e "s/@VERSION@/${VERSION}/" \
        -e "s/@PACKAGE@/${PACKAGE_NAME}/" \
        -e "s/@SOL_PACKAGE@/${SOL_PACKAGE}/" \
        -e "s/@MAINTAINER@/${MAINTAINER}/" \
        -e "s/@STANDARD_DEPEND@/${STANDARD_DEPEND}/" \
        -e "s/@SO_VERSION@/${LIBRARY_VERSION}/" \
        -e "s/@ARCHITECTURE@/${ARCHITECTURE}/" \
        $1 > $2
}

function build_package {
    ########################################################################
    # Package housekeeping                                                 #
    ########################################################################

    # Copy unrunnable files
    test -f ${PROJECT_NAME}.conffiles \
            && cp ${PROJECT_NAME}.conffiles ${CONTROL_DIR}/conffiles

    VERSION=$(< ../version)
    ARCHITECTURE=$(uname -p)

    # Process control file -- all @tags@ will be replaced with
    # appropriate data.
    replace_vars ${PROJECT_NAME}.pkginfo ${SOLARIS_BASE}/pkginfo

    # Create protocol file
    (echo "i pkginfo=${SOLARIS_BASE}/pkginfo"; cd ${ROOT_DIR}; pkgproto .) \
        > ${SOLARIS_BASE}/prototype

    # Make package
    (cd ${ROOT_DIR}; pkgmk -o -r / \
        -f ${SOLARIS_BASE}/prototype -d ${PACKAGE_DIR} ${SOL_PACKAGE})

    # Trasnform package
    pkgtrans ${PACKAGE_DIR} \
        ${PACKAGE_NAME}.${VERSION}.${ARCHITECTURE}.pkg \
        ${SOL_PACKAGE}

    # Get rid of temporary build directory.
    rm -r ${BUILD_DIR} ${PACKAGE_DIR}/${SOL_PACKAGE}
}

# determine operation
if [ "${MODE}" = "binary" ]; then
    # we are making 'bin' package -- called recursively from make.sh
    # Make all directories
    make_dirs

    ########################################################################
    # Copy all files                                                       #
    ########################################################################

    # lib files
    mkdir -p ${ROOT_DIR}/usr/lib
    cp -vd ${INSTALL_DIR}/usr/lib/*.so.* ${ROOT_DIR}/usr/lib

    # build extra depend
    SH_DEPEND=''

    # Build the package
    build_package
    exit $?

elif [ "${MODE}" = "dev" ]; then
    # we are making 'dev' package -- called recursively from make.sh
    BINARY_PROJECT_NAME=${PROJECT_NAME}
    PROJECT_NAME=${PROJECT_NAME}-dev

    # Make all directories
    make_dirs

    ########################################################################
    # Copy all files                                                       #
    ########################################################################

    # headers
    mkdir -p ${ROOT_DIR}/usr/include
    cp -vrd ${INSTALL_DIR}/usr/include/* ${ROOT_DIR}/usr/include

    # lib files
    mkdir -p ${ROOT_DIR}/usr/lib
    cp -vd ${INSTALL_DIR}/usr/lib/*.a ${ROOT_DIR}/usr/lib
    cp -vd ${INSTALL_DIR}/usr/lib/*.la ${ROOT_DIR}/usr/lib
    cp -vd ${INSTALL_DIR}/usr/lib/*.so ${ROOT_DIR}/usr/lib

    # Compose extra dependencies: we must depend on libfastrpc library with
    # exactly same version.
    VERSION=$(< ../version)
    EXTRA_DEPEND=szn-"${BINARY_PROJECT_NAME}${LIBRARY_VERSION} (= ${VERSION})"

    # Build the package
    build_package
    exit $?
else
    # check for fakeroot
    if ! fakeroot true; then
        echo "You need fakeroot to run this."
        exit -2
    fi
fi

# Installation

########################################################################
# Build and install.                                                   #
########################################################################

# project name
PROJECT_NAME="libfastrpc"

# Maintainer of this module
MAINTAINER="Vaclav Blazek <blazek@firma.seznam.cz>"

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
        PROCESSORS=$( (cat /proc/cpuinfo || echo processor) \
                | grep ^processor | wc -l)

        # go to the project root
        cd ..

        # configure sources -- we want to instal under /usr
        # info goes to share dir
        ./configure --prefix=/usr --infodir=/usr/share/info
        # clean any previously created files
        make clean
        # make libfastrpc
        make -j ${PROCESSORS} all
    )
fi

# Install to temporary directory.
if test -z "${SKIP_INSTALL}"; then
    (
        cd ..
        # install libfastrpc to the install-dir
        make DESTDIR=${INSTALL_DIR} install
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
        ${INSTALL_DIR}/usr/lib/libfastrpc.la) || exit -1

export PROJECT_NAME
export MAINTAINER
export INSTALL_DIR
export DEBUG

# Create binary package (must be run under fakeroot).
fakeroot ./make.sh --make-binary

# Create dev package (must be run under fakeroot).
fakeroot ./make.sh --make-dev

# Get rid of residuals
rm -Rf ${INSTALL_DIR}
