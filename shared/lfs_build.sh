#!/bin/bash

set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH

pushd () {
  command pushd "$@" > /dev/null
}

popd () {
  command popd "$@" > /dev/null
}

cd $LFS/sources

# compile binutils (pass 1)
echo "Building binutils (pass 1)..."
tar -xf binutils-2.32.tar.xz
mkdir -p binutils-2.32/build
pushd binutils-2.32/build
../configure --prefix=/tools \
  --with-sysroot=$LFS        \
  --with-lib-path=/tools/lib \
  --target=$LFS_TGT          \
  --disable-nls              \
  --disable-werror
make
mkdir -p /tools/lib && ln -sf lib /tools/lib64
make install
popd
rm -fr binutils-2.32
echo "Finished building binutils (pass 1)."

# compile gcc (pass 1)
echo "Building gcc (pass 1)..."
tar -xf gcc-8.2.0.tar.xz
pushd gcc-8.2.0
tar -xf ../mpfr-4.0.2.tar.xz
mv mpfr-4.0.2 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv gmp-6.1.2 gmp
tar -xf ../mpc-1.1.0.tar.gz
mv mpc-1.1.0 mpc
for file in gcc/config/{linux,i386/linux{,64}}.h
do
  cp -u $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
mkdir -p build
cd build
../configure                                     \
  --target=$LFS_TGT                              \
  --prefix=/tools                                \
  --with-glibc-version=2.11                      \
  --with-sysroot=$LFS                            \
  --with-newlib                                  \
  --without-headers                              \
  --with-local-prefix=/tools                     \
  --with-native-system-header-dir=/tools/include \
  --disable-nls                                  \
  --disable-shared                               \
  --disable-multilib                             \
  --disable-decimal-float                        \
  --disable-threads                              \
  --disable-libatomic                            \
  --disable-libgomp                              \
  --disable-libmpx                               \
  --disable-libquadmath                          \
  --disable-libssp                               \
  --disable-libvtv                               \
  --disable-libstdcxx                            \
  --enable-languages=c,c++
make
make install
popd
rm -fr gcc-8.2.0
echo "Finished building gcc (pass 1)."

# install linux headers
echo "Installing linux headers..."
tar -xf linux-4.20.12.tar.xz
pushd linux-4.20.12
make mrproper
make INSTALL_HDR_PATH=dest headers_install
cp -r dest/include/* /tools/include
popd
rm -fr linux-4.20.12
echo "Finished installing linux headers."

# build glib
echo "Building glib..."
tar -xf glibc-2.29.tar.xz
pushd glibc-2.29
mkdir -p build
cd build
../configure                         \
  --prefix=/tools                    \
  --host=$LFS_TGT                    \
  --build=$(../scripts/config.guess) \
  --enable-kernel=3.2                \
  --with-headers=/tools/include
make
make install
popd
rm -fr glibc-2.29
echo "Finished building glib."

# build libstdc++
echo "Building libstdc++..."
tar -xf gcc-8.2.0.tar.xz
pushd gcc-8.2.0
mkdir build
cd build
../libstdc++-v3/configure         \
  --host=$LFS_TGT                 \
  --prefix=/tools                 \
  --disable-multilib              \
  --disable-nls                   \
  --disable-libstdcxx-threads     \
  --disable-libstdcxx-pch         \
  --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/8.2.0
make
make install
popd
rm -fr gcc-8.2.0
echo "Finished building libstdc++."

# compile binutils (pass 2)
echo "Building binutils (pass 2)..."
tar -xf binutils-2.32.tar.xz
mkdir -p binutils-2.32/build
pushd binutils-2.32/build
CC=$LFS_TGT-gcc              \
AR=$LFS_TGT-ar               \
RANLIB=$LFS_TGT-ranlib       \
../configure                 \
  --prefix=/tools            \
  --disable-nls              \
  --disable-werror           \
  --with-lib-path=/tools/lib \
  --with-sysroot
make
make install
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp ld/ld-new /tools/bin
popd
rm -fr binutils-2.32
echo "Finished building binutils (pass 2)."

# compile gcc (pass 2)
echo "Building gcc (pass 2)..."
tar -xf gcc-8.2.0.tar.xz
pushd gcc-8.2.0
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
for file in gcc/config/{linux,i386/linux{,64}}.h
do
  cp -u $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done
sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
tar -xf ../mpfr-4.0.2.tar.xz
mv mpfr-4.0.2 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv gmp-6.1.2 gmp
tar -xf ../mpc-1.1.0.tar.gz
mv mpc-1.1.0 mpc
mkdir build
cd build
CC=$LFS_TGT-gcc                                  \
CXX=$LFS_TGT-g++                                 \
AR=$LFS_TGT-ar                                   \
RANLIB=$LFS_TGT-ranlib                           \
../configure                                     \
  --prefix=/tools                                \
  --with-local-prefix=/tools                     \
  --with-native-system-header-dir=/tools/include \
  --enable-languages=c,c++                       \
  --disable-libstdcxx-pch                        \
  --disable-multilib                             \
  --disable-bootstrap                            \
  --disable-libgomp
make
make install
ln -s gcc /tools/bin/cc
popd
rm -fr gcc-8.2.0
echo "Finished building gcc (pass 2)."

echo "Building tcl..."
tar -xf tcl8.6.9-src.tar.gz
pushd tcl8.6.9/unix
./configure --prefix=/tools
make
make install
chmod u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -s tclsh8.6 /tools/bin/tclsh
popd
rm -fr tcl8.6.9
echo "Finished building tcl."

echo "Building expect..."
tar -xf expect5.45.4.tar.gz
pushd expect5.45.4
cp configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools \
  --with-tcl=/tools/lib     \
  --with-tclinclude=/tools/include
make
make SCRIPTS="" install
popd
rm -fr expect5.45.4
echo "Finished building expect."

echo "Building DejaGNU..."
tar -xf dejagnu-1.6.2.tar.gz
pushd dejagnu-1.6.2
./configure --prefix=/tools
make install
popd
rm -fr dejagnu-1.6.2
echo "Finished building DejaDNU."

echo "Building M4..."
tar -xf m4-1.4.18.tar.xz
pushd m4-1.4.18
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/tools
make
make install
popd
rm -fr m4-1.4.18
echo "Finished building M4."

echo "Building ncurses..."
tar -xf ncurses-6.1.tar.gz
pushd ncurses-6.1
sed -i s/mawk// configure
./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite
make
make install
ln -s libncursesw.so /tools/lib/libncurses.so
popd
rm -fr ncurses-6.1
echo "Finished building ncurses."
