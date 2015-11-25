# Note: This is only a guess at what needs to be done
# to create the libpbc_core.so object from pbc_core.o.
# It's really just a simple function.
#
# I used some combination of
# -I/Applications/VMD\ 1.9.2.app/Contents/Frameworks/Tcl.framework/Headers
# -L/Applications/VMD\ 1.9.2.app/Contents/Frameworks/Tcl.framework/Versions/8.5
# -ltclstub8.5
# -DUSE_TCL_STUBS
# -shared
# -o libpbc_core.so
# pbc_core.c
#
# e.g.
#   gcc -m32 -shared -o libpbc_core.so -DUSE_TCL_STUBS -I"$TCLINC" pbc_core.c -L"$TCLLIB" -ltclstub8.5
#
# Also of note on OSX are the system frameworks:
#   -I/System/Library/Frameworks/Tcl.framework/Versions/8.5/Headers
#   -L/System/Library/Frameworks/Tcl.framework/Versions/8.5
#

AR= ar
ARFLAGS = cr
RANLIB = ranlib
COMPILEDIR = ../compile
INCDIR=-Isrc
SRCDIR=src

#CXXFLAGS = -g $(CXXFLAGS)
CXXFLAGS += -g

VMFILES = pbcbox.tcl pbcgui.tcl pbcjoin.tcl pbcset.tcl pbctools.tcl \
	pbcunwrap.tcl pbcwrap.tcl pkgIndex.tcl

VMVERSION = 3.0
ARCHDIR=${COMPILEDIR}/lib_${ARCH}/tcl/pbctools$(VMVERSION)

VPATH = src ${ARCHDIR}

# only build so if we have a Tcl library
ifdef TCLLIB
ifdef TCLINC
ifdef TCLLDFLAGS
    TARGETS = ${ARCHDIR} ${ARCHDIR}/libpbc_core.so
endif
endif
endif

bins:
win32bins:
dynlibs: $(TARGETS)
staticlibs:
win32staticlibs:

distrib:
	for localname in `find ../compile -name libpbc_core.so -print` ; do \
		pluginname=`echo $$localname | sed s/..\\\/compile\\\/lib_// `; \
		dir=`dirname $(PLUGINDIR)/$$pluginname`; \
		mkdir -p $$dir; \
		cp $$localname $(PLUGINDIR)/$$pluginname; \
		cp $(VMFILES) $$dir ; \
	done
${ARCHDIR}:
	mkdir -p ${ARCHDIR}

LIBPBCOBJS=${ARCHDIR}/pbc_core.o

${ARCHDIR}/libpbc_core.so: ${LIBPBCOBJS}
	if [ -n "${TCLSHLD}" ]; \
	then ${TCLSHLD} $(LOPTO)$@ ${LIBPBCOBJS} ${TCLLIB} ${TCLLDFLAGS} ${LDFLAGS}; \
	else ${SHLD} $(LOPTO)$@ ${LIBPBCOBJS} ${TCLLIB} ${TCLLDFLAGS} ${LDFLAGS}; \
	fi

${ARCHDIR}/pbc_core.o: pbc_core.c
	${CXX} ${CXXFLAGS} ${TCLINC} ${INCDIR} -c ${SRCDIR}/pbc_core.c $(COPTO)${ARCHDIR}/pbc_core.o

