#!/usr/bin/bash
#
# {{{ CDDL HEADER
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source. A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
# }}}

# Copyright 2016 OmniTI Computer Consulting, Inc.  All rights reserved.
# Copyright 2021 OmniOS Community Edition (OmniOSce) Association.

. ../../lib/functions.sh

PROG=postgresql
PKG=ooce/database/postgresql-13
VER=13.4
SUMMARY="PostgreSQL 13"
DESC="The World's Most Advanced Open Source Relational Database"

SKIP_LICENCES=postgresql

MAJVER=${VER%.*}            # M.m
sMAJVER=${MAJVER//./}       # Mm
set_patchdir patches-$sMAJVER

OPREFIX=$PREFIX
PREFIX+=/pgsql-$MAJVER
CONFPATH=/etc$PREFIX
LOGPATH=/var/log$PREFIX
VARPATH=/var$PREFIX
RUNPATH=$VARPATH/run

reset_configure_opts

XFORM_ARGS="
    -DPREFIX=${PREFIX#/}
    -DOPREFIX=${OPREFIX#/}
    -DPROG=$PROG
    -DPKGROOT=pgsql-$MAJVER
    -DMEDIATOR=$PROG -DMEDIATOR_VERSION=$MAJVER
    -DVERSION=$MAJVER
    -DsVERSION=$sMAJVER
"

CFLAGS+=" -O3"

CONFIGURE_OPTS="
    --prefix=$PREFIX
    --sysconfdir=$CONFPATH
    --localstatedir=$VARPATH
    --enable-thread-safety
    --with-openssl
    --with-libxml
    --with-xslt
    --with-readline
    --without-systemd
    --with-system-tzdata=/usr/share/lib/zoneinfo
"

CONFIGURE_OPTS_64+="
    --bindir=$PREFIX/bin
    --enable-dtrace DTRACEFLAGS=-64
"

# need to build world to get e.g. man pages in
MAKE_TARGET=world
MAKE_INSTALL_TARGET=install-world

build_manifests() {
    manifest_start $TMPDIR/manifest.client
    manifest_add_dir $PREFIX/include libpq
    manifest_add_dir $PREFIX/lib/pkgconfig
    manifest_add_dir $PREFIX/lib/$ISAPART64/pkgconfig
    manifest_add $PREFIX/lib '.*lib(pq\.|ecpg|pgtypes|pgcommon|pgport).*'
    manifest_add $PREFIX/bin '.*pg_config' psql ecpg
    manifest_add $PREFIX/share/man/man1 pg_config.1 psql.1 ecpg.1
    manifest_add $PREFIX/share psqlrc.sample
    manifest_finalise $OPREFIX

    manifest_uniq $TMPDIR/manifest.{server,client}
}

# Make ISA binaries for pg_config, to allow software to find the
# right settings for 32/64-bit when pkg-config is not used.
make_isa_stub() {
    pushd $DESTDIR$PREFIX/bin >/dev/null
    logcmd mkdir -p $ISAPART64
    logcmd mv pg_config $ISAPART64/ || logerr "mv pg_config"
    make_isaexec_stub_arch $ISAPART64 $PREFIX/bin
    popd >/dev/null
}

init
download_source $PROG $PROG $VER
patch_source
prep_build
build
make_isa_stub
#run_testsuite check-world
xform files/postgres.xml > $TMPDIR/$PROG-$sMAJVER.xml
install_smf ooce $PROG-$sMAJVER.xml
build_manifests
PKG=${PKG/database/library} SUMMARY+=" client and libraries" \
    make_package -seed $TMPDIR/manifest.client
RUN_DEPENDS_IPS="ooce/database/postgresql-common" \
    make_package -seed $TMPDIR/manifest.server server.mog
clean_up

# Vim hints
# vim:ts=4:sw=4:et:fdm=marker
