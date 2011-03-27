//
//  XTPanAdapterView.h
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
#import <QuartzCore/CoreAnimation.h>

#import "TransceiverController.h"
#import "XTPanadapterDataMUX.h"
#import "XTWorkerThread.h"
#import "XTPanadapterLayer.h"
#import "XTWaterfallView.h"

@interface XTPanAdapterView : NSView {
	
	XTWorkerThread *updateThread;
	
	float subPosition;
	float hzPerUnit;
	
	float zoomFactor;
	
	CAScrollLayer *rootLayer;
	CALayer *tickLayer;
	CALayer *frequencyLayer;
	XTPanadapterLayer *waveLayer;
	
	NSBezierPath *path;
	
	NSRect filterRect, leftFilterBoundaryRect, rightFilterBoundaryRect;
	NSRect subFilterRect, subFilterHotRect, leftSubFilterBoundaryRect, rightSubFilterBoundaryRect;
	
	BOOL dragging;
	BOOL startedRight;
	BOOL startedLeft;
	BOOL startedSubLeft;
	BOOL startedSubRight;
	BOOL startedSub;
		
	float lowPanLevel, highPanLevel;
	
	IBOutlet TransceiverController *transceiverController;
	IBOutlet XTPanadapterDataMUX *dataMux;
	IBOutlet NSControl *zoomControl;
	IBOutlet XTWaterfallView *waterView;
}

@property float lowPanLevel;
@property float highPanLevel;
@property float zoomFactor;

-(void)doNotification: (NSNotification *) notification;

-(IBAction)zoomIn: (id) sender;
-(IBAction)zoomOut: (id) sender;

-(void) observeValueForKeyPath: (NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context: (void *) context;
@end
