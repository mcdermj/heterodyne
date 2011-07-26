/** 
* @file dttsp.h
* @brief DttSP interface definitions
* @author John Melton, G0ORX/N6LYT, Doxygen Comments Dave Larsen, KV0S
* @version 0.1
* @date 2009-04-11
*/
// dttsp.h

/* Copyright (C) 
* 2009 - John Melton, G0ORX/N6LYT, Doxygen Comments Dave Larsen, KV0S
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation; either version 2
* of the License, or (at your option) any later version.
* 
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
* 
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
* 
*/




//
// what we know about DttSP
//

#define MAXRX 4

typedef enum _agcmode
{ agcOFF, agcLONG, agcSLOW, agcMED, agcFAST } AGCMODE;

typedef enum _trxmode { RX, TX } TRXMODE;

typedef enum _runmode
{
	RUN_MUTE, RUN_PASS, RUN_PLAY, RUN_SWCH
} RUNMODE;

typedef enum _sdrmode
{
	LSB,                          //  0
	USB,                          //  1
	DSB,                          //  2
	CWL,                          //  3
	CWU,                          //  4
	FMN,                          //  5
	AM,                           //  6
	DIGU,                         //  7
	SPEC,                         //  8
	DIGL,                         //  9
	SAM,                          // 10
	DRM                           // 11
} SDRMODE;

typedef unsigned int BOOLEAN;

extern void Setup_SDR();
extern void Release_Update();
extern void SetThreadCom(int thread);
extern void Audio_Callback (float *input_l, float *input_r, float *output_l,
                            float *output_r, unsigned int nframes, int thread);
extern void Process_Spectrum (int thread, float *results);
extern void Process_Panadapter (int thread, float *results);
extern void Process_Phase (int thread, float *results, int numpoints);
extern void Process_Scope (int thread, float *results, int numpoints);
extern float CalculateRXMeter(int thread,unsigned int subrx, int mt);
extern int SetSampleRate(double sampleRate);
extern int SetRXOsc(unsigned int thread, unsigned subrx, double freq);
extern int SetRXOutputGain(unsigned int thread, unsigned subrx, double gain);
extern int SetRXPan(unsigned int thread, unsigned subrx, float pos);
extern int reset_for_buflen (unsigned int, int);
extern void SetTRX (unsigned int thread, TRXMODE setit);
extern void SetThreadProcessingMode(unsigned int thread, RUNMODE runmode);
extern int SetSubRXSt(unsigned int thread, unsigned int subrx, BOOLEAN setit);
extern int SetRXFilter (unsigned int thread, unsigned int subrx, double low_frequency, double high_frequency);
extern int SetTXFilter (unsigned int thread, double low_frequency, double high_frequency);
extern int SetMode (unsigned int thread, unsigned int subrx, SDRMODE m);
extern void SetRXAGC (unsigned int thread, unsigned subrx, AGCMODE setit);
extern void SetNR (unsigned int thread, unsigned subrx, BOOLEAN setit);
extern void SetANF (unsigned int thread, unsigned subrx, BOOLEAN setit);
extern void SetNB (unsigned int thread, unsigned subrx, BOOLEAN setit);
extern void SetBIN (unsigned int thread, unsigned subrx, BOOLEAN setit);
extern void SetTXOsc(unsigned int thread, double freq);