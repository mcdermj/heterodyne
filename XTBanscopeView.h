//
//  XTBanscopeView.h
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

// $Id$

#import <Cocoa/Cocoa.h>
#import <Accelerate/Accelerate.h>

@class TransceiverController;
@protocol XTHeterodyneHardwareDriver;

@interface XTBanscopeView : NSView {
	
	id<XTHeterodyneHardwareDriver> interface;
	IBOutlet TransceiverController *controller;
	
	NSBezierPath *background;
	NSBezierPath *path;
	NSBezierPath *mainFrequency;
	NSBezierPath *subFrequency;
	NSMutableArray *bandAreas;
	
	NSMutableArray *tickMarks;
	NSMutableDictionary *textAttributes;
	
	CALayer *rootLayer;
	
	float width, height;
	float xCenter;
	float scale;
	float slope;
	float hzPerUnit;
	float startFrequency, endFrequency;
	float highBandscopeLevel, lowBandscopeLevel;
	float mainPosition, subPosition;
	
	float *blackmanHarris;
	float samples[4098];
	float averageSmoothing;
	
	COMPLEX_SPLIT fftIn;
	float *fftOut; // 4096
	float *results;
	float *average;
	float *smoothed;
	float *y; // 2048
	float smoothValue, negativeLowBandscopeLevel;
	
	FFTSetup fftSetup;

	BOOL initAverage;
	
	float min, max;
	int counter;

}

@property float highBandscopeLevel;
@property float lowBandscopeLevel;

-(void)dataReady;
-(void)doBoundsChanged:(NSNotification *)theNotification;
-(void)doDefaultsNotification:(NSNotification *)notification;
-(void)calculatePath:(NSData *)bandscopeData;
-(void)calculateTickMarks;

-(float *)blackmanHarrisFilter: (int)n;


@end
