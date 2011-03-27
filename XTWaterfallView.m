//
//  XTWaterfallView.m
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

#import "XTWaterfallView.h"

#import "TransceiverController.h"
#import "XTWaterfallLayer.h"
#import "XTWorkerThread.h"

#import <mach/mach.h>
#import <mach/mach_time.h>

#include <OpenGL/gl.h>
#include <OpenGL/glu.h>

@implementation XTWaterfallView

@synthesize flowsUp;
@synthesize zoomFactor;

-(id)initWithFrame:(NSRect)frameRect {
	[super initWithFrame:frameRect];
	
	if(self) {
		zoomFactor = 1.0;
		flowsUp = NO;
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(boundsHaveChanged) 
													 name:NSViewFrameDidChangeNotification 
												   object:nil];
		
		rootLayer = [CAScrollLayer layer];
		rootLayer.name = @"rootLayer";
		rootLayer.bounds = NSRectToCGRect(self.bounds);
		rootLayer.layoutManager = [CAConstraintLayoutManager layoutManager];
		rootLayer.scrollMode = kCAScrollHorizontally;		
		
		waterfallLayer = [XTWaterfallLayer layer];
		[waterfallLayer setFlowsUp:flowsUp];
		waterfallLayer.name = @"waterfallLayer";
		
		waterfallLayer.bounds = CGRectMake(0.0, 0.0, NSWidth(self.bounds), 0.0);
		
		CAConstraint *yCentered = 
		[CAConstraint constraintWithAttribute:kCAConstraintMidY 
								   relativeTo:@"superlayer" 
									attribute:kCAConstraintMidY];
		CAConstraint *xCentered =
		[CAConstraint constraintWithAttribute:kCAConstraintMidX 
								   relativeTo:@"superlayer" 
									attribute:kCAConstraintMidX];
		
		CAConstraint *ySameSize =
		[CAConstraint constraintWithAttribute:kCAConstraintHeight 
								   relativeTo:@"superlayer" 
									attribute:kCAConstraintHeight];
				
		[waterfallLayer addConstraint:yCentered];
		[waterfallLayer addConstraint:xCentered];
		[waterfallLayer addConstraint:ySameSize];
		[waterfallLayer setNeedsDisplayOnBoundsChange:YES];
		[rootLayer addSublayer:waterfallLayer];		
		
		[self setLayer: rootLayer];
		[self setWantsLayer:YES];
	}
	
	return self;
}

-(void)setFlowsUp:(BOOL)doesFlowUp {
	flowsUp = doesFlowUp;
	[waterfallLayer setFlowsUp:doesFlowUp];
}

-(void)awakeFromNib {
	hzPerUnit = [[NSUserDefaults standardUserDefaults] floatForKey:@"sampleRate"] / NSWidth(self.bounds);
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(dataReady) 
												 name:@"XTPanAdapterDataReady" 
											   object: dataMux];		
	
	[waterfallLayer setDataMUX:dataMux];	
}

-(void)dataReady {
	[waterfallLayer performSelector:@selector(setNeedsDisplay)
						   onThread:[transceiverController updateThread]
						 withObject:nil
					  waitUntilDone:NO];
}


-(void)doDefaultsNotification: (NSNotification *) notification {
	NSString *notificationName = [notification name];
	
	if(notificationName == NSUserDefaultsDidChangeNotification ) {		
		hzPerUnit = [[NSUserDefaults standardUserDefaults] floatForKey:@"sampleRate"] / NSWidth(self.bounds);
	}
}

-(void)mouseDragged: (NSEvent *)theEvent {
	if(dragging == NO) {
		[[NSCursor closedHandCursor] push];
		dragging = YES;
	}
	transceiverController.frequency -= [theEvent deltaX] * hzPerUnit;
}

-(void)mouseUp: (NSEvent *)theEvent {
	if([theEvent clickCount] == 0) {
		// Dragging
		transceiverController.frequency += [theEvent deltaX] * hzPerUnit;
		dragging = NO;
		[NSCursor pop];
		
	} else {
		// Click or Double-Click
		NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView: nil];
		transceiverController.frequency += (clickPoint.x - NSMidX(self.bounds)) * hzPerUnit;
	}
}

-(void)scrollWheel:(NSEvent *)theEvent {
	transceiverController.frequency += [theEvent deltaY] * hzPerUnit;
}

-(void)boundsHaveChanged {
	waterfallLayer.bounds = CGRectMake(0.0, 0.0, NSWidth(self.bounds) * zoomFactor, 0.0);
}

-(void)setZoomFactor:(float)newZoomFactor {
	if(newZoomFactor < 1.0) return;
	zoomFactor = newZoomFactor;
	
		
	waterfallLayer.bounds = CGRectMake(0.0, 0.0, NSWidth(self.bounds) * zoomFactor, 0.0);
	[rootLayer scrollToRect:CGRectMake(CGRectGetWidth(rootLayer.bounds) / 4.0, 0, CGRectGetWidth(rootLayer.bounds) / 2.0, CGRectGetHeight(rootLayer.bounds))];
}

-(BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
    return [NSApp isActive];
}

@end
