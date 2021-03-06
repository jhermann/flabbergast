AC_INIT([flabbergast-glib], [1.0], [andre@masella.name], [flabbergast-glib], [http://github.com/apmasell/flabbergast-glib])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_HEADERS(config.h)
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE([1.11 dist-bzip2])
AM_MAINTAINER_MODE

m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])], )

# Checks for programs.
AC_PROG_CC
AM_PROG_CC_C_O
AC_DISABLE_STATIC
AC_PROG_LIBTOOL
AC_PROG_LN_S

AC_PATH_PROG(VALAC, valac, valac)
AC_SUBST(VALAC)

AC_PATH_PROG(VALADOC, valadoc, valadoc)
AC_SUBST(VALADOC)
AM_CONDITIONAL([ENABLE_VALADOC], [test -n "$VALADOC"])

AC_SUBST(VALAFLAGS)
AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

GLIB_REQUIRED=2.16.0
PKG_CHECK_MODULES(GLIB, glib-2.0 >= $GLIB_REQUIRED gobject-2.0 >= $GLIB_REQUIRED)
AC_SUBST(GLIB_CFLAGS)
AC_SUBST(GLIB_LIBS)

PKG_CHECK_MODULES(GEE, gee-0.8)
AC_SUBST(GEE_CFLAGS)
AC_SUBST(GEE_LIBS)

PKG_CHECK_MODULES(GTEONOMA, libgteonoma-1)
AC_SUBST(GTEONOMA_CFLAGS)
AC_SUBST(GTEONOMA_LIBS)

OLD_LIBS="$LIBS"
AX_LIB_READLINE
READLINE_LIBS="$LIBS"
AC_SUBST(READLINE_LIBS)
LIBS="$OLD_LIBS"

PACKAGE_MAJOR="$(echo "$PACKAGE_VERSION" | cut -f 1 -d .)"
AC_SUBST(PACKAGE_MAJOR)

AC_CONFIG_FILES([
	Makefile
]) 
AC_CONFIG_FILES(${PACKAGE_NAME}-${PACKAGE_MAJOR}.pc:lib.pc.in, [], [PACKAGE_NAME=$PACKAGE_NAME PACKAGE_MAJOR=$PACKAGE_MAJOR ])
AC_CONFIG_FILES(${PACKAGE_NAME}-${PACKAGE_MAJOR}.deps:lib.deps.in, [], [PACKAGE_NAME=$PACKAGE_NAME PACKAGE_MAJOR=$PACKAGE_MAJOR ])
AC_CONFIG_FILES([update-flabbergast:update-flabbergast.in], [chmod +x update-flabbergast])
AC_OUTPUT
