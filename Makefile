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
# -I/System/Library/Frameworks/Tcl.framework/Versions/8.5/Headers
# -L/System/Library/Frameworks/Tcl.framework/Versions/8.5
#
# with 
# gcc -m32 -shared -o libpbc_core.so -DUSE_TCL_STUBS -I"$TCLINC" pbc_core.c -L"$TCLLIB" -ltclstub8.5

.SUFFIXES:

.SILENT:

AR= ar
ARFLAGS = cr
RANLIB = ranlib
COMPILEDIR = ../compile
INCDIR=-Isrc
#CXXFLAGS = -g $(CXXFLAGS)
CXXFLAGS += -g

VMFILES = pbcbox.tcl pbcgui.tcl pbcjoin.tcl pbcset.tcl pbctools.tcl \
	pbcunwrap.tcl pbcwrap.tcl pkgIndex.tcl

VMVERSION = 2.8
DIR = $(PLUGINDIR)/noarch/tcl/pbctools$(VMVERSION)
VPATH=$(DIR)

# only build so if we have a Tcl library
ifdef TCLLIB
ifdef TCLINC
ifdef TCLLDFLAGS
    TARGETS = $(DIR) $(PLUGINDIR)/libpbc_core.so
endif
endif
endif

bins:
win32bins:
dynlibs: $(TARGETS)
staticlibs:
win32staticlibs:

distrib:
	@echo "Copying pbctools $(VMVERSION) files to $(DIR)"
	mkdir -p $(DIR) 
	cp $(COMPILEDIR)/libpbc_core.so $(PLUGINDIR)/$$pluginname;
	cp $(VMFILES) $(DIR) 


${DIR}/libpbc_core.so: pbc_core.o
	if [ -n "${TCLSHLD}" ]; \
	then ${TCLSHLD} $(LOPTO)$@ pbc_core.o ${TCLLIB} ${TCLLDFLAGS} ${LDFLAGS}; \
	else ${SHLD} $(LOPTO)$@ pbc_core.o ${TCLLIB} ${TCLLDFLAGS} ${LDFLAGS}; \
	fi

pbc_core.o: pbc_core.c
	${CXX} ${CXXFLAGS} -g ${TCLINC} ${INCDIR} -D_${ARCH} -c $< $(COPTO) $@

