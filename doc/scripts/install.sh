#!/bin/bash

# This script will download EGG and its dependencies and build the
# program without requiring any interaction from you.
#
# The script sequence is:
#
# 1) Download the CFITSIO, WCSLib and vif libraries and build them
# 2) Download EGG, build it, install it
#
# To use this script, just make it executable, and run it. Your current
# directory does not matter and will not be modified. Example:
#
# chmod +x install.sh
# ./install.sh
#
# You may have to edit the script if you don't want to (or cannot) use
# the system-default locations to install EGG. See below for more
# information.


# -----------------------------------------
# Configurable options
# -----------------------------------------
#
# Modify if needed.

# INSTALL_ROOT_DIR: the location where EGG will be installed. Leave
# empty to install it in the system default folders. You should manually
# specify this directory only if you do not want it to be installed
# system-wise or if you do not have root access on your computer. In any
# case this has to be an absolute path.
#
# See the INSTALL file in the vif directory or the doc.pdf file
# in the EGG directory if you get into trouble.

# Example:
# INSTALL_ROOT_DIR="/opt/local"
# Default: (system default)
INSTALL_ROOT_DIR=""

CFITSIO_VERSION="_latest"
WCSLIB_VERSION=""
VIF_VERSION="master"
EGG_VERSION="latest"


# -----------------------------------------
# Prepare installation
# -----------------------------------------

function abort {
    echo ""
    echo ""
    echo "Oops, there was an error in the installation process."
    echo "Make sure that all the dependencies are properly installed"
    echo "and that your compiler is supported by 'vif'."
    echo ""
    cd $TMP_DIR
    exit 1
}

trap 'abort' 0
set -e

TMP_DIR=`mktemp -d 2>/dev/null || mktemp -d -t 'egg-tmp-dir'`
cd $TMP_DIR
echo $TMP_DIR


# -----------------------------------------
# The CFITSIO library
# -----------------------------------------

# Download and extract it
wget "http://heasarc.gsfc.nasa.gov/FTP/software/fitsio/c/cfitsio"$CFITSIO_VERSION".tar.gz" \
   -O "cfitsio"$CFITSIO_VERSION".tar.gz"
tar -xvzf "cfitsio"$CFITSIO_VERSION".tar.gz" && rm "cfitsio"$CFITSIO_VERSION".tar.gz"

# Configure it
cd cfitsio
./configure --prefix=`pwd`/../

# Build it
make install
cd $TMP_DIR


# -----------------------------------------
# The WCSLib library
# -----------------------------------------

# Download and extract it
wget "ftp://ftp.atnf.csiro.au/pub/software/wcslib/wcslib"$WCSLIB_VERSION".tar.bz2" \
   -O "wcslib"$WCSLIB_VERSION".tar.bz2"
tar -xvjf "wcslib"$WCSLIB_VERSION".tar.bz2" && rm "wcslib"$WCSLIB_VERSION".tar.bz2"

# Configure it
cd wcslib*
./configure --prefix=`pwd`/../ --with-cfitsioinc=../include --with-cfitsiolib=../lib \
   --without-pgplot --disable-fortran --disable-utils

# Build it
make install
# Remove dynamic libaries which we do not want to find in CMake
DYNLIBS=`find ../lib | grep -E "\.(so|dylib)"`
if [ -n "$DYNLIBS" ]; then
    rm $DYNLIBS
fi
cd $TMP_DIR


# -----------------------------------------
# The vif library
# -----------------------------------------

# Download and extract it
wget https://github.com/cschreib/vif/archive/$VIF_VERSION.tar.gz \
    --no-check-certificate -O $VIF_VERSION.tar.gz
tar -xvzf $VIF_VERSION.tar.gz && rm $VIF_VERSION.tar.gz

# Configure it
mkdir -p vif-$VIF_VERSION/build && cd vif-$VIF_VERSION/build
# Make sure that the temporary path in the top search list to find CFITSIO and WCSLib
CMAKE_INCLUDE_PATH="$TMP_DIR/include:$CMAKE_INCLUDE_PATH"
CMAKE_LIBRARY_PATH="$TMP_DIR/lib:$CMAKE_LIBRARY_PATH"
cmake ../ -DCMAKE_INSTALL_PREFIX=$TMP_DIR -DCFITSIO_ROOT_DIR=$TMP_DIR -DWCSLIB_ROOT_DIR=$TMP_DIR \
    -DNO_REFLECTION=1 -DNO_GSL=1 -DNO_LAPACK=1 -DNO_LIBUNWIND=1 -DNO_LIBDWARF=1 -DNO_PROFILER=1 \
    -DVIF_INPLACE_BUILD=1

# Build it
make install
cd $TMP_DIR


# -----------------------------------------
# EGG
# -----------------------------------------

# Get latest version name
if [ "$EGG_VERSION" = "latest" ]; then
    EGG_VERSION=$(curl -s https://api.github.com/repos/cschreib/egg/releases/latest | grep tag_name \
        | sed 's/"tag_name": "//g' | sed 's/",//g' | tr -d '[:space:]')
fi

# Download and extract it
wget https://github.com/cschreib/egg/archive/$EGG_VERSION.tar.gz \
    --no-check-certificate -O $EGG_VERSION.tar.gz
tar -xvzf $EGG_VERSION.tar.gz && rm $EGG_VERSION.tar.gz

# Configure it
EGG_DIR=egg-$(echo $EGG_VERSION | sed "s/v//g")
mkdir -p $EGG_DIR/build && cd $EGG_DIR/build
if [ -n "$INSTALL_ROOT_DIR" ]; then
    DINSTALL_ROOT_DIR="-DCMAKE_INSTALL_PREFIX=$INSTALL_ROOT_DIR"
fi
cmake ../  $DINSTALL_ROOT_DIR \
    -DCFITSIO_ROOT_DIR=$TMP_DIR -DWCSLIB_ROOT_DIR=$TMP_DIR -DVIF_ROOT_DIR=$TMP_DIR \
    -DNO_REFLECTION=1 -DNO_GSL=1 -DNO_LAPACK=1 -DNO_LIBUNWIND=1 -DNO_LIBDWARF=1 -DNO_PROFILER=1

# Extract install dir from CMake to check if we need sudo
if [ -z "$INSTALL_ROOT_DIR" ]; then
    INSTALL_ROOT_DIR=`cat CMakeCache.txt | grep CMAKE_INSTALL_PREFIX | sed "s/CMAKE_INSTALL_PREFIX:PATH=//g"`
fi

mkdir -p $INSTALL_ROOT_DIR

# Build and install it
make
if [ -w "$INSTALL_ROOT_DIR" ]; then
    make install
else
    sudo make install
fi
cd $TMP_DIR


# -----------------------------------------
# End of install, you made it!
# -----------------------------------------

trap : 0

echo ""
echo ""
echo "   -----------------------------------"
echo "   EGG has been successfuly installed!"
echo "   -----------------------------------"
echo ""
