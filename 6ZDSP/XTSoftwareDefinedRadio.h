//
//  XTSoftwareDefinedRadio.h
//  MacHPSDR
//
//  Copyright (c) 2010 - Jeremy C. McDermond (NH6Z)

// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

// $Id: XTSoftwareDefinedRadio.h 141 2010-03-18 21:19:57Z mcdermj $

#import <Cocoa/Cocoa.h>

#import <OpenCL/OpenCL.h>

@class XTDSPBlock;
@class XTWorkerThread;
@class XTDSPSpectrumTap;
@class XTDSPBandpassFilter;
@class XTDSPAutomaticGainControl;
@class XTRealData;

@interface XTSoftwareDefinedRadio : NSObject {
	
	NSMutableArray *dspModules;
	
	XTWorkerThread *workerThread;
	
	float sampleRate;
	
	XTDSPSpectrumTap *spectrumTap;
	XTDSPBandpassFilter *ifFilter;
	XTDSPAutomaticGainControl *agc;
	
	cl_context openClContext;
}

@property float sampleRate;

-(id)initWithSampleRate: (float)initialSampleRate;
-(void)processComplexSamples: (XTDSPBlock *)complexData;
-(void)tapSpectrumWithRealData:(XTRealData *)spectrumData;

-(void)setHighCut:(float)highCutoff;
-(void)setLowCut:(float)lowCutoff;

-(void)initOpenCL;

@end
