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

echo "Building bash..."
tar -xf bash-5.0.tar.gz
pushd bash-5.0
./configure --prefix=/tools --without-bash-malloc
make
make install
ln -s bash /tools/bin/sh
popd
rm -fr bash-5.0
echo "Finished building bash."

echo "Building bison..."
tar -xf bison-3.3.2.tar.xz
pushd bison-3.3.2
./configure --prefix=/tools
make
make install
popd
rm -fr bison-3.3.2
echo "Finished building bison."

echo "Building bzip2..."
tar -xf bzip2-1.0.6.tar.gz
pushd bzip2-1.0.6
make
make PREFIX=/tools install
popd
rm -fr bzip2-1.0.6
echo "Finished building bzip2."

echo "Building coreutils..."
tar -xf coreutils-8.30.tar.xz
pushd coreutils-8.30
./configure --prefix=/tools --enable-install-program=hostname
make
make install
popd
rm -fr coreutils-8.30
echo "Finished building coreutils."

echo "Building diffutils..."
tar -xf diffutils-3.7.tar.xz
pushd diffutils-3.7
./configure --prefix=/tools
make
make install
popd
rm -fr diffutil-3.7
echo "Finished building diffutil."

echo "Building file..."
tar -xf file-5.36.tar.gz
pushd file-5.36
./configure --prefix=/tools
make
make install
popd
rm -fr file-5.36
echo "Finished building file."

echo "Building findutils..."
tar -xf findutils-4.6.0.tar.gz
pushd findutils-4.6.0
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h
./configure --prefix=/tools
make
make install
popd
rm -fr findutils-4.6.0
echo "Finished building findutils."

echo "Building gawk..."
tar -xf gawk-4.2.1.tar.xz
pushd gawk-4.2.1
./configure --prefix=/tools
make
make install
popd
rm -fr gawk-4.2.1
echo "Finished building gawk."

echo "Building gettext..."
tar -xf gettext-0.19.8.1.tar.xz
pushd gettext-0.19.8.1
cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared
make -C gnulib-lib
make -C intl pluralx.c
make -C src msgfmt
make -C src msgmerge
make -C src xgettext
cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin
popd
rm -fr gettext-0.19.8.1
echo "Finished building gettext."

echo "Building grep..."
tar -xf grep-3.3.tar.xz
pushd grep-3.3
./configure --prefix=/tools
make
make install
popd
rm -fr grep-3.3
echo "Finished building grep."

echo "Building gzip..."
tar -xf gzip-1.10.tar.xz
pushd gzip-1.10
./configure --prefix=/tools
make
make install
popd
rm -fr gzip-1.10
echo "Finished building gzip."

echo "Building make..."
tar -xf make-4.2.1.tar.bz2
pushd make-4.2.1
sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
./configure --prefix=/tools --without-guile
make
make install
popd
rm -fr make-4.2.1
echo "Finished building make."

echo "Building patch..."
tar -xf patch-2.7.6.tar.xz
pushd patch-2.7.6
./configure --prefix=/tools
make
make install
popd
rm -fr patch-2.7.6
echo "Finished building patch-2.7.6"

echo "Building perl..."
tar -xf perl-5.28.1.tar.xz
pushd perl-5.28.1
sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth
make
cp -v perl cpan/podlators/scripts/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.28.1
cp -Rv lib/* /tools/lib/perl5/5.28.1
popd
rm -fr perl-5.28.1
echo "Finished building perl-5.28.1"

echo "Building Python..."
tar -xf Python-3.7.2.tar.xz
pushd Python-3.7.2
sed -i '/def add_multiarch_paths/a \        return' setup.py
./configure --prefix=/tools --without-ensurepip
make
make install
popd
rm -fr Python-3.7.2
echo "Finished building Python-3.7.2"

echo "Building sed..."
tar -xf sed-4.7.tar.xz
pushd sed-4.7
./configure --prefix=/tools
make
make install
popd
rm -fr sed-4.7
echo "Finished building sed-4.7"

echo "Building tar..."
tar -xf tar-1.31.tar.xz
pushd tar-1.31
./configure --prefix=/tools
make
make install
popd
rm -fr tar-1.31
echo "Finished building tar-1.31"

echo "Building texinfo..."
tar -xf texinfo-6.5.tar.xz
pushd texinfo-6.5
./configure --prefix=/tools
make
make install
popd
rm -fr texinfo-6.5
echo "Finished building texinfo-6.5"

echo "Building xz..."
tar -xf xz-5.2.4.tar.xz
pushd xz-5.2.4
./configure --prefix=/tools
make
make install
popd
rm -fr xz-5.2.4
echo "Finished building xz-5.2.4"

strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*
rm -rf /tools/{,share}/{info,man,doc}
find /tools/{lib,libexec} -name \*.la -delete
