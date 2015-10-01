/*  pbc_core.c -- written by David M. Rogers, Univ. South Florida
 *
 *  This file implements a solver for the closest integer vector
 * problem (decode), and uses it to wrap to arbitrary (3D)
 * minimal unit cells.
 *
 * The code is released under the terms of the BSD2 license.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <tcl.h>

#define PBC_CORE_VERSION "2.8"

double round(double);

static void decode(double L[3][3], int n, double *x);

/*
int main(int argc, char **argv) {
	const double L[3][3] = {{1.0, 0.0, 0.0},{0.5, 0.8660254, 0.0},{0.5, 0.28867513, 0.81649658}};
	double pt[3];
	int i;
	
	if(argc != 4) {
		printf("Usage: %s <x> <y> <z>\n", argv[0]);
		return 1;
	}
	for(i=0;i<3;i++) {
		pt[i] = atof(argv[i+1]);
	}
	printf("%f %f %f\n", pt[0], pt[1], pt[2]);
	decode(L, 1, pt);
	printf("%f %f %f\n", pt[0], pt[1], pt[2]);
	return 0;
} */

/* Decode a list of 'n' 3D points, x, into nearest lattice points.
 * L is assumed to be lower-triangular.
 * This replaces x with the minimum images.
 */
static void decode(double L[3][3], int n, double *x) {
	double C[3], x1[2], x0, Cmax, d2[3];
	int ref[3], pt[3], delta[3], s[3], xp[3];
	int i;
	
	Cmax =    L[0][0]*L[0][0]
		+ L[1][0]*L[1][0]+L[1][1]*L[1][1]
		+ L[2][0]*L[2][0]+L[2][1]*L[2][1]+L[2][2]*L[2][2];
	for(i=0; i<n; i++, x+=3) {
		C[2] = Cmax;
		pt[2] = ref[2] = round(x[2]/L[2][2]);
		delta[2] = 0;
		s[2] = 2*(L[2][2]*pt[2] < x[2])-1; // sign of delta
		d2[2] = pt[2]*L[2][2]-x[2];
		d2[2] *= d2[2];
		while(d2[2] < C[2]) {
			x1[0] = x[0]-pt[2]*L[2][0]; 
			x1[1] = x[1]-pt[2]*L[2][1];
			C[1] = C[2]-d2[2]; // remaining distance.
			pt[1] = ref[1] = round(x1[1]/L[1][1]);
			delta[1] = 0;
			s[1] = 2*(L[1][1]*pt[1] < x1[1])-1;
			d2[1] = pt[1]*L[1][1]-x1[1];
			d2[1] *= d2[1];
			while(d2[1] < C[1]) {
				x0 = x1[0]-pt[1]*L[1][0];
				//C[0] = C[1]-d2[1];
				pt[0] = round(x0/L[0][0]);
				d2[0] = pt[0]*L[0][0]-x0;
				d2[0] *= d2[0];
				//printf("pt[0]=%d, d2=%f, max=%f\n", pt[0],d2[0],C[1]-d2[1]);
				//if(d2[0] < C[0]) { // found new min. pt.
				if(d2[0] < C[1]-d2[1]) {
					xp[0] = pt[0];
					xp[1] = pt[1];
					xp[2] = pt[2];
					//C[0] = d2[0];
					C[1] = d2[0]+d2[1];
				}
				delta[1] = -delta[1] + (delta[1]<=0);
				pt[1] = ref[1]+s[1]*delta[1];
				d2[1] = pt[1]*L[1][1]-x1[1];
				d2[1] *= d2[1];
				//printf("pt[1]=%d, d2=%f, max=%f\n", pt[1],d2[1],C[1]);
			}
			C[2] = C[1]+d2[2];
			// step
			delta[2] = -delta[2] + (delta[2]<=0);
			pt[2] = ref[2]+s[2]*delta[2];
			d2[2] = pt[2]*L[2][2]-x[2];
			d2[2] *= d2[2];
			//printf("pt[2]=%d, d2=%f, max=%f\n", pt[2],d2[2],C[2]);
		}
                // x -= n^T L
                x[0] -= xp[0]*L[0][0] + xp[1]*L[1][0] + xp[2]*L[2][0];
                x[1] -= xp[1]*L[1][1] + xp[2]*L[2][1];
                x[2] -= xp[2]*L[2][2];
	}
}

// String -> TCL List -> double x[3]
// name is a string for error reporting purposes
#define PARSE_VEC(name, obj, vec) { \
    Tcl_Obj **coorObj; \
    int ndim; \
    if(Tcl_ListObjGetElements(interp, obj, &ndim, &coorObj) != TCL_OK) { \
        return TCL_ERROR; \
    } \
    if(ndim != 3) { \
        Tcl_SetObjResult(interp, \
                    Tcl_NewStringObj(name " must be 3D", -1)); \
        return TCL_ERROR; \
    } \
    Tcl_GetDoubleFromObj(interp, coorObj[0], &vec[0]); \
    Tcl_GetDoubleFromObj(interp, coorObj[1], &vec[1]); \
    Tcl_GetDoubleFromObj(interp, coorObj[2], &vec[2]); \
}

// TCL wrapper
int tcl_decode(ClientData nodata, Tcl_Interp *interp,
               int objc, Tcl_Obj *const objv[]) {
    Tcl_Obj **cell, **vecs;
    double *cartcoor, *x, L[3][3], orig[3];
    int i, n, ndim;

    if (objc != 4) {
         Tcl_WrongNumArgs(interp, 1, objv, "cell orig vecs");
         return TCL_ERROR;
    }
    // Parse origin first
    PARSE_VEC("origin", objv[2], orig);

    // Then unit cell
    if(Tcl_ListObjGetElements(interp, objv[1], &ndim, &cell) != TCL_OK) {
        return TCL_ERROR;
    }
    if(ndim != 3) {
        Tcl_SetObjResult(interp,
                        Tcl_NewStringObj("3 lattice vectors required", -1));
        return TCL_ERROR;
    }
    for(i=0; i<3; i++) {
        PARSE_VEC("lattice vectors", cell[i], L[i]);
    }

    // Finally, parse coordinates.
    if(Tcl_ListObjGetElements(interp, objv[3], &n, &vecs) != TCL_OK) {
        return TCL_ERROR;
    }

    x = cartcoor = malloc(sizeof(double)*3*n);
    for(i=0; i<n; i++, x+=3) {
        PARSE_VEC("coordinates", vecs[i], x);
    }
    x = cartcoor;

    decode(L, n, x); // actual work
    
    Tcl_Obj *y = Tcl_NewListObj(0, NULL);
    /* build result with translated coordinates */
    for(i=0; i<n; i++, x += 3) {
        Tcl_Obj *xyz[3] = {
            Tcl_NewDoubleObj(x[0]),
            Tcl_NewDoubleObj(x[1]),
            Tcl_NewDoubleObj(x[2])
        };
        Tcl_ListObjAppendElement(interp, y, Tcl_NewListObj(3, xyz));
    }
    Tcl_SetObjResult(interp, y);

    free(cartcoor);
    return TCL_OK;
}

/* register the plugin with the tcl interpreters */
int DLLEXPORT Pbc_core_Init(Tcl_Interp *interp) {
    if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
        return TCL_ERROR;
    }
    if(Tcl_PkgProvide(interp, "pbc_core", PBC_CORE_VERSION) == TCL_ERROR) {
        return TCL_ERROR;
    }
    Tcl_CreateObjCommand(interp, "wrap_min", tcl_decode, NULL, NULL);
    return TCL_OK;
}

// stutter skills
int DLLEXPORT Pbc_core_SafeInit(Tcl_Interp *interp) {
    return Pbc_core_Init(interp);
}
int Pbc_core_Unload(Tcl_Interp *interp, int flags) { return TCL_OK; }
int Pbc_core_SafeUnload(Tcl_Interp *interp, int flags) {
    return Pbc_core_Unload(interp, flags);
}


