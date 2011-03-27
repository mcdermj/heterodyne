/* cxops.h
This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2004, 2005, 2006 by Frank Brickle, AB2KT and Bob McGwier, N4HY

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

The authors can be reached by email at

ab2kt@arrl.net
or
rwmcgwier@comcast.net

or by paper mail at

The DTTS Microwave Society
6 Kathleen Place
Bridgewater, NJ 08807
*/

#ifndef _cxops_h

#define _cxops_h

#include <dttsp-complex.h>
#include <datatypes.h>
#include <fastrig.h>

extern DTTSPCOMPLEX cxzero;
extern DTTSPCOMPLEX cxone;
extern DTTSPCOMPLEX cxJ;
extern DTTSPCOMPLEX cxminusone;
extern DTTSPCOMPLEX cxminusJ;


// scalar

static INLINE DTTSPCOMPLEX Cscl  (DTTSPCOMPLEX x, REAL a)
{
 DTTSPCOMPLEX z;
	c_re (z) = c_re (x) * a;
	c_im (z) = c_im (x) * a;
	return z;
}

static INLINE DTTSPCOMPLEX Cadd  (DTTSPCOMPLEX x, DTTSPCOMPLEX y)
{
 DTTSPCOMPLEX z;
	c_re (z) = c_re (x) + c_re (y);
	c_im (z) = c_im (x) + c_im (y);
	return z;
}

static INLINE DTTSPCOMPLEX Csub  (DTTSPCOMPLEX x, DTTSPCOMPLEX y)
{
 DTTSPCOMPLEX z;
	c_re (z) = c_re (x) - c_re (y);
	c_im (z) = c_im (x) - c_im (y);
	return z;
}

static INLINE DTTSPCOMPLEX Cmul  (DTTSPCOMPLEX x, DTTSPCOMPLEX y)
{
 DTTSPCOMPLEX z;
	c_re (z) = c_re (x) * c_re (y) - c_im (x) * c_im (y);
	c_im (z) = c_im (x) * c_re (y) + c_re (x) * c_im (y);
	return z;
}

static INLINE DTTSPCOMPLEX Cdiv  (DTTSPCOMPLEX x, DTTSPCOMPLEX y)
{
	REAL d = sqr (c_re (y)) + sqr (c_im (y));
 DTTSPCOMPLEX z;
	c_re (z) = (c_re (x) * c_re (y) + c_im (x) * c_im (y)) / d;
	c_im (z) = (c_re (y) * c_im (x) - c_im (y) * c_re (x)) / d;
	return z;
}

static INLINE REAL
Cappmag (DTTSPCOMPLEX z)
{
	REAL tmpr = (REAL)fabs(z.re);
	REAL tmpi = (REAL)fabs(z.im);
	REAL tmp = (tmpr < tmpi ? 0.4f*tmpr + 0.7f*tmpi : 0.4f*tmpi + 0.7f*tmpr);
	return tmp;
}

static INLINE REAL
Cmag  (DTTSPCOMPLEX z)
{
	return (REAL) sqrt (sqr (z.re) + sqr (z.im));
	//return (REAL) hypot(z.re,z.im);
}

static INLINE REAL
Cabs  (DTTSPCOMPLEX z)
{
	return (REAL) sqrt (sqr (z.re) + sqr (z.im));
}

static INLINE REAL
Csqrmag  (DTTSPCOMPLEX z)
{
	return (REAL) (sqr (z.re) + sqr (z.im));
}

static INLINE DTTSPCOMPLEX Cmplx (REAL x, IMAG y)
{
 DTTSPCOMPLEX z;
	z.re = x, z.im = y;
	return z;
}

static INLINE DTTSPCOMPLEX Conjg  (DTTSPCOMPLEX z)
{
	return Cmplx (z.re, -z.im);
}

static INLINE DTTSPCOMPLEX Cexp  (DTTSPCOMPLEX z)
{
	REAL r = (REAL) exp (z.re);
	return Cmplx ((REAL) (r * cos (z.im)), (IMAG) (r * sin (z.im)));
}

static INLINE DTTSPCOMPLEX Cp2r  (DTTSPCOMPLEX z)
{
	return Cmplx ((REAL) (z.re * cos (z.im)), (IMAG) (z.re * sin (z.im)));
}

static INLINE DTTSPCOMPLEX Cr2p  (DTTSPCOMPLEX z)
{
	return Cmplx (
		(REAL) (sqrt (sqr (z.re) + sqr (z.im))),
		//(REAL) hypot(z.re,z.im),
		(REAL) atan2 (z.im, z.re));
}
typedef struct SSEVEC
{
	float a,b,c,d;
} ssevec;

#endif
