//
//  XTPanAdapterView.m
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

#import "XTPanAdapterView.h"

#import "XTWorkerThread.h"
#import "XTMainWindowController.h"
#import "TransceiverController.h"
#import "XTReceiver.h"
#import "XTPanadapterDataMUX.h"

#import <Accelerate/Accelerate.h>

#include <OpenGL/gl.h>
#include <OpenGL/glu.h>

@implementation XTPanAdapterView

@synthesize lowLevel;
@synthesize highLevel;
@synthesize windowController;

-(id)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	if(self) {				
		path = [[NSBezierPath alloc] init];
		[path setLineWidth:0.5];
		
 		startedLeft = startedRight = dragging = NO;		
        
		rootLayer = [CALayer layer];
		rootLayer.name = @"rootLayer";
		rootLayer.bounds = NSRectToCGRect(self.bounds);
		rootLayer.layoutManager = [CAConstraintLayoutManager layoutManager];
		
		tickLayer = [CALayer layer];
		tickLayer.name = @"tickLayer";
				
		frequencyLayer = [CALayer layer];
		frequencyLayer.name = @"frequencyLayer";
		
		waveLayer = [XTPanadapterLayer layer];
		waveLayer.name = @"waveLayer";
		
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
		
		CAConstraint *xWidthOfTicks =
		[CAConstraint constraintWithAttribute:kCAConstraintWidth 
								   relativeTo:@"tickLayer" 
									attribute:kCAConstraintWidth];
		
		CAConstraint *xSameSize =
		[CAConstraint constraintWithAttribute:kCAConstraintWidth 
								   relativeTo:@"superlayer" 
									attribute:kCAConstraintWidth];
		
		[tickLayer addConstraint:yCentered];
		[tickLayer addConstraint:xCentered];
		[tickLayer addConstraint:ySameSize];
		[tickLayer addConstraint:xSameSize];
		[tickLayer setNeedsDisplayOnBoundsChange:YES];
		[tickLayer setDelegate: self];
		[rootLayer addSublayer:tickLayer];
		
		[frequencyLayer addConstraint:yCentered];
		[frequencyLayer addConstraint:xCentered];
		[frequencyLayer addConstraint:ySameSize];
		[frequencyLayer addConstraint:xWidthOfTicks];
		[frequencyLayer setNeedsDisplayOnBoundsChange:YES];
		[frequencyLayer setDelegate: self];
		[rootLayer addSublayer:frequencyLayer];
		
		[waveLayer addConstraint:yCentered];
		[waveLayer addConstraint:xCentered];
		[waveLayer addConstraint:ySameSize];
		[waveLayer addConstraint:xWidthOfTicks];
		[waveLayer setNeedsDisplayOnBoundsChange:YES];
		[rootLayer addSublayer:waveLayer];
		
		[self setLayer: rootLayer];
		[rootLayer setDelegate: self];
		[self setWantsLayer:YES];
		
		updateThread = [[XTWorkerThread alloc] init];
		[updateThread start];
	}
	return self;
}

-(void)awakeFromNib {	
    [self bind:@"lowLevel" 
      toObject:[NSUserDefaultsController sharedUserDefaultsController]
   withKeyPath:@"values.lowPanLevel" 
       options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] 
                                           forKey:@"NSContinuouslyUpdatesValue"]];
    
    [self bind:@"highLevel" 
      toObject:[NSUserDefaultsController sharedUserDefaultsController]
   withKeyPath:@"values.highPanLevel" 
       options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] 
                                           forKey:@"NSContinuouslyUpdatesValue"]];
		
	filterRect = NSMakeRect(NSMidX(self.bounds) + ([windowController transceiver].filterLow / hzPerUnit), 
                            0, 
                            ([windowController transceiver].filterHigh / hzPerUnit) - ([windowController transceiver].filterLow / hzPerUnit),
                            NSHeight(self.bounds));	
	subFilterRect = NSMakeRect(subPosition + ([windowController transceiver].subFilterLow / hzPerUnit), 
                               0, ([windowController transceiver].subFilterHigh / hzPerUnit) - ([windowController transceiver].subFilterLow / hzPerUnit), 
                               NSHeight(self.bounds));

	[[self window] invalidateCursorRectsForView:self];
    
    // XXX This should be a loop around an array of XTReceivers to observe their filter and frequency changes.
    // XXX We also should be changing the drawing layers to draw an arbitrary number of receivers on the display.
	
	[[XTReceiver mainReceiver] addObserver:self 
							forKeyPath:@"filterLow" 
							   options:NSKeyValueObservingOptionNew 
							   context: NULL];	
	[[XTReceiver mainReceiver] addObserver:self 
							forKeyPath:@"filterHigh" 
							   options:NSKeyValueObservingOptionNew 
							   context: NULL];
	[[XTReceiver mainReceiver] addObserver:self 
							forKeyPath:@"frequency" 
							   options:NSKeyValueObservingOptionNew 
							   context: NULL];
    
	[[windowController transceiver] addObserver:self 
							forKeyPath:@"subFrequency" 
							   options:NSKeyValueObservingOptionNew 
							   context: NULL];
	[[windowController transceiver] addObserver:self 
							forKeyPath:@"subFilterLow" 
							   options:NSKeyValueObservingOptionNew 
							   context: NULL];	
	[[windowController transceiver] addObserver:self 
							forKeyPath:@"subFilterHigh" 
							   options:NSKeyValueObservingOptionNew 
							   context: NULL];
	[[windowController transceiver] addObserver:self 
							forKeyPath:@"subEnabled" 
							   options:NSKeyValueObservingOptionNew 
							   context:NULL];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(dataReady) 
												 name:@"XTPanAdapterDataReady" 
											   object: dataMux];
	
	[waveLayer setDataMUX:dataMux];	
}

-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
	NSGraphicsContext *nsGraphicsContext;
	nsGraphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:ctx 
																   flipped: NO];
	
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:nsGraphicsContext];
	
	if(layer.name == @"tickLayer") {
		//  Recalculate all the tick layer parameters here
		//  We can do it here because this only should be called when we need to
		//  Actually draw the layer
		NSBezierPath *tickMark;
		NSString *tickMarkLabel;
		float mark, position;
		float startFrequency, endFrequency;
		
		hzPerUnit = (float) [windowController transceiver].sampleRate / CGRectGetWidth(layer.bounds);
        dbPerUnit = (float) (highLevel - lowLevel) / CGRectGetHeight(layer.bounds);
		startFrequency = ((float) [windowController transceiver].frequency) - (CGRectGetMidX(layer.bounds) * hzPerUnit);
		endFrequency = startFrequency + (CGRectGetWidth(layer.bounds) * hzPerUnit);
		
		
		NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor lightGrayColor], NSForegroundColorAttributeName, 
						  [NSFont fontWithName:@"Monaco" size:9.0], NSFontAttributeName,
						  nil];		
		
		// Clear the window
		NSBezierPath *background = [[NSBezierPath alloc] init];
		[background appendBezierPathWithRect:NSRectFromCGRect(layer.bounds)];
		[[NSColor whiteColor] set];
		[background fill];		
		
		[[NSColor lightGrayColor] set];
		for(mark = ceilf(startFrequency / 10000.0) * 10000.0; mark < endFrequency; mark += 10000.0) {
			position = (mark - startFrequency) / hzPerUnit;
			
			tickMark = [[NSBezierPath alloc] init];
			[tickMark setLineWidth: 0.5];
			[tickMark moveToPoint: NSMakePoint(position, 0)];
			[tickMark lineToPoint: NSMakePoint(position, CGRectGetHeight(layer.bounds))];
			[tickMark stroke];
			
			tickMarkLabel = [NSString stringWithFormat:@"%d", (int) (mark / 1000.0)];
			[tickMarkLabel drawAtPoint:NSMakePoint(position + 4, CGRectGetHeight(layer.bounds) - 15) 
						withAttributes:textAttributes];
		}
		
		float slope = CGRectGetHeight(layer.bounds) / (highLevel - lowLevel);
		
		for(mark = ceilf(lowLevel / 10.0) * 10.0; mark < highLevel; mark += 10.0) {
			position = (mark - lowLevel) * slope;
			
			tickMark = [[NSBezierPath alloc] init];
			[tickMark setLineWidth: 0.5];
			[tickMark moveToPoint: NSMakePoint(0, position)];
			[tickMark lineToPoint: NSMakePoint(CGRectGetWidth(layer.bounds), position)];
			[tickMark stroke];
			
			tickMarkLabel = [NSString stringWithFormat:@"%d dB", (int) mark];
			[tickMarkLabel drawAtPoint:NSMakePoint(4, position - 15) 
						withAttributes:textAttributes];
		}
		
		
	} else if(layer.name == @"frequencyLayer") {
		float startFrequency;
        //, endFrequency;
		
		hzPerUnit = (float) [windowController transceiver].sampleRate / CGRectGetWidth(layer.bounds);
		startFrequency = ((float) [windowController transceiver].frequency) - (CGRectGetMidX(layer.bounds) * hzPerUnit);
		// endFrequency = startFrequency + (CGRectGetWidth(layer.bounds) * hzPerUnit);

		NSBezierPath *centerLine = [[NSBezierPath alloc] init];
		[centerLine setLineWidth:0.5];
		[centerLine moveToPoint:NSMakePoint(CGRectGetMidX(layer.bounds), 0)];
		[centerLine lineToPoint:NSMakePoint(CGRectGetMidX(layer.bounds), CGRectGetHeight(layer.bounds))];
		[[NSColor redColor] set];
		[centerLine stroke];

		if([windowController transceiver].subEnabled == TRUE) {
			subPosition = ([windowController transceiver].subFrequency - startFrequency) / hzPerUnit;
			
			NSBezierPath *subLine = [[NSBezierPath alloc] init];
			[subLine setLineWidth:0.5];
			[subLine moveToPoint:NSMakePoint(subPosition, 0)];
			[subLine lineToPoint:NSMakePoint(subPosition, CGRectGetHeight(layer.bounds))];											 
			[[NSColor blueColor] set];
			[subLine stroke];
			
			subFilterRect = NSMakeRect(subPosition + ([windowController transceiver].subFilterLow / hzPerUnit), 
									   0, 
									   ([windowController transceiver].subFilterHigh / hzPerUnit) - ([windowController transceiver].subFilterLow / hzPerUnit), 
									   CGRectGetHeight(layer.bounds));
			
			NSBezierPath *subFilter = [[NSBezierPath alloc] init];
			[subFilter appendBezierPathWithRect:subFilterRect];
			[[NSColor colorWithDeviceRed:0.0 green:0.0 blue:1.0 alpha:0.1] set];
			[subFilter fill];
			
		}
											 
		NSDictionary *bandPlan = [[windowController transceiver] bandPlan];
		NSRange panadapterRange = NSMakeRange(startFrequency, [windowController transceiver].sampleRate);
		for(id band in bandPlan) {
			int start = [[[bandPlan objectForKey:band] objectForKey:@"start"] intValue];
			int length = [[[bandPlan objectForKey:band] objectForKey:@"end"] intValue] - start;
			NSRange bandRange = NSMakeRange(start, length);
			NSRange intersectionRange = NSIntersectionRange(bandRange, panadapterRange);
			if(intersectionRange.length != 0) {
				NSRect bandEdgeRect = NSMakeRect((intersectionRange.location - startFrequency) / hzPerUnit, 
										  0, 
										  intersectionRange.length / hzPerUnit, 
										  CGRectGetHeight(layer.bounds));
				
				NSBezierPath *bandEdges = [[NSBezierPath alloc] init];
				[bandEdges setLineWidth:0.5];
				[bandEdges appendBezierPathWithRect:bandEdgeRect];
				[[NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:0.05] set];
				[bandEdges fill];
				[[NSColor greenColor] set];
				[bandEdges stroke];				
			}
		}		
		
		filterRect = NSMakeRect(CGRectGetMidX(layer.bounds) + ([[XTReceiver mainReceiver] filterLow] / hzPerUnit), 
								0, 
								([[XTReceiver mainReceiver] filterHigh] / hzPerUnit) - ([[XTReceiver mainReceiver] filterLow ] / hzPerUnit), 
								CGRectGetHeight(layer.bounds));
		NSBezierPath *filter = [[NSBezierPath alloc] init];
		[filter appendBezierPathWithRect:filterRect];
		[[NSColor colorWithDeviceRed:1.0 green:0.0 blue:0.0 alpha:0.1] set];
		[filter fill];
		
		[self.window invalidateCursorRectsForView:self];
		
	} else if(layer.name == @"waveLayer") {
		int i;
		
		float x = 0;
		float *y;
		float negativeLowPanLevel;
		
		float slope = CGRectGetHeight(layer.bounds) / (highLevel - lowLevel);
				
		[path removeAllPoints];
		
		// Get the buffer
		NSData *panData = [dataMux smoothBufferData];
		
		float scale = CGRectGetWidth(layer.bounds) / (float) ([panData length] / sizeof(float));
		
		const float *smoothBuffer = [panData bytes];
		y = malloc([panData length]);
		
		negativeLowPanLevel = -lowLevel;
		vDSP_vsadd((float *) smoothBuffer, 1, &negativeLowPanLevel, y, 1, [panData length] / sizeof(float));
		vDSP_vsmul(y, 1, &slope, y, 1, [panData length] / sizeof(float)); 
		
		for(i = 1; i < ([panData length] / sizeof(float)) - 1; ++i) {
			x = i * scale;
			
			if(i == 1) {
				[path moveToPoint:NSMakePoint(x, y[i])];
			} else {
				[path lineToPoint:NSMakePoint(x, y[i])];
			}
		}
		
		free(y);
		
		[[NSColor blackColor] set];
		[path stroke];
	}

	[NSGraphicsContext restoreGraphicsState];
}

-(void)dataReady {
	[waveLayer performSelector:@selector(setNeedsDisplay)
					  onThread:updateThread
					withObject:nil
				 waitUntilDone:NO];
}

-(void)doNotification: (NSNotification *) notification {
	NSString *notificationName = [notification name];
	
	if(notification == nil || notificationName == NSUserDefaultsDidChangeNotification ) {
		lowLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"lowPanLevel"];
		highLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"highPanLevel"];
		
		[tickLayer setNeedsDisplay];
	}

}

-(void)mouseDown:(NSEvent *)theEvent {
	NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView: nil];
	if(NSPointInRect(clickPoint, leftFilterBoundaryRect)) {
		startedLeft = YES;
	} else if(NSPointInRect(clickPoint, rightFilterBoundaryRect)) {
		startedRight = YES;
	} else if([windowController transceiver].subEnabled == YES) {
		if(NSPointInRect(clickPoint, leftSubFilterBoundaryRect)) {
			startedSubLeft = YES;
		} else if(NSPointInRect(clickPoint, rightSubFilterBoundaryRect)) {
			startedSubRight = YES;
		} else if(NSPointInRect(clickPoint, subFilterHotRect)) {
			startedSub = YES;
		}
	}
}

-(void)mouseDragged: (NSEvent *)theEvent {
	if([theEvent modifierFlags] & NSAlternateKeyMask) return;
	
	if(startedLeft == YES) {
		[windowController transceiver].filterHigh += [theEvent deltaX] * hzPerUnit;
	} else if(startedRight == YES) {
		[windowController transceiver].filterLow += [theEvent deltaX] * hzPerUnit;
	} else if(startedSubLeft == YES) {
		[windowController transceiver].subFilterHigh += [theEvent deltaX] * hzPerUnit;
	} else if(startedSubRight == YES) {
		[windowController transceiver].subFilterLow += [theEvent deltaX] * hzPerUnit;
	} else if(startedSub == YES) {
		if([[NSCursor currentCursor] isNotEqualTo:[NSCursor closedHandCursor]]) {
			[[NSCursor closedHandCursor] push];
		}		
		[windowController transceiver].subFrequency += [theEvent deltaX] * hzPerUnit;
	} else {
		dragging = YES;
		if([[NSCursor currentCursor] isNotEqualTo:[NSCursor closedHandCursor]]) {
			[[NSCursor closedHandCursor] push];
		}
        self.highLevel += [theEvent deltaY] * dbPerUnit;
        self.lowLevel += [theEvent deltaY] * dbPerUnit;
		[windowController transceiver].frequency -= [theEvent deltaX] * hzPerUnit;
	} 
}

-(void)mouseUp: (NSEvent *)theEvent {
	if([theEvent clickCount] == 0) {
		// Dragging
		if(startedLeft == YES) {
			[windowController transceiver].filterHigh += [theEvent deltaX] * hzPerUnit;
		} else if (startedRight == YES) {
			[windowController transceiver].filterLow += [theEvent deltaX] * hzPerUnit;
		} else if(startedSubLeft == YES) {
			[windowController transceiver].subFilterHigh += [theEvent deltaX] * hzPerUnit;
		} else if(startedSubRight == YES) {
			[windowController transceiver].subFilterLow += [theEvent deltaX] * hzPerUnit;
		} else if(startedSub == YES) {
			[windowController transceiver].subFrequency += [theEvent deltaX] * hzPerUnit;
			[NSCursor pop];			
		} else {
            self.highLevel += [theEvent deltaY] * dbPerUnit;
            self.lowLevel += [theEvent deltaY] * dbPerUnit;
			[windowController transceiver].frequency -= [theEvent deltaX] * hzPerUnit;
			[NSCursor pop];
		}
	} else {
		// Click or Double-Click
		NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView: nil];
		if([theEvent modifierFlags] & NSAlternateKeyMask) {
			if([windowController transceiver].subEnabled == TRUE) {
				[windowController transceiver].subFrequency += (clickPoint.x - subPosition) * hzPerUnit;
			}
		} else {
			[windowController transceiver].frequency += (clickPoint.x - NSMidX(self.bounds)) * hzPerUnit;
		}
	}
	startedLeft = startedRight = startedSubLeft = startedSubRight = startedSub = dragging = NO;
}

-(void)rightMouseUp:(NSEvent *)theEvent {
	if([windowController transceiver].subEnabled == TRUE && [theEvent clickCount] > 0) {
		NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView: nil];
		[windowController transceiver].subFrequency += (clickPoint.x - subPosition) * hzPerUnit;
	}
}

-(void)scrollWheel:(NSEvent *)theEvent {
	if([theEvent modifierFlags] & NSAlternateKeyMask) {
		if([windowController transceiver].subEnabled == TRUE) {
			[windowController transceiver].subFrequency += [theEvent deltaY] * hzPerUnit;
		}
	} else {
		[windowController transceiver].frequency += [theEvent deltaY] * hzPerUnit;
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{	
	[frequencyLayer setNeedsDisplay];
	[tickLayer setNeedsDisplay];
}

-(void)resetCursorRects {
	rightFilterBoundaryRect = NSMakeRect(NSMinX(filterRect) - 3, 
										 0, 
										 6, 
										 NSHeight(self.bounds));
	rightFilterBoundaryRect = NSRectFromCGRect([tickLayer convertRect:NSRectToCGRect(rightFilterBoundaryRect)
											 toLayer:rootLayer]);
	
	leftFilterBoundaryRect = NSMakeRect(NSMaxX(filterRect) - 3,
										0,
										6, 
										NSHeight(self.bounds));
	leftFilterBoundaryRect = NSRectFromCGRect([tickLayer convertRect:NSRectToCGRect(leftFilterBoundaryRect)
											toLayer:rootLayer]);
	
	rightSubFilterBoundaryRect = NSMakeRect(NSMinX(subFilterRect) - 3,
											0,
											6,
											NSHeight(self.bounds));
	rightSubFilterBoundaryRect = NSRectFromCGRect([tickLayer convertRect:NSRectToCGRect(rightSubFilterBoundaryRect)
												toLayer:rootLayer]);
	
	leftSubFilterBoundaryRect = NSMakeRect(NSMaxX(subFilterRect) - 3,
										   0,
										   6,
										   NSHeight(self.bounds));
	leftSubFilterBoundaryRect = NSRectFromCGRect([tickLayer convertRect:NSRectToCGRect(leftSubFilterBoundaryRect)
											   toLayer:rootLayer]);
	
	if(dragging == YES || startedSub == YES) {
		[self addCursorRect:self.bounds cursor:[NSCursor currentCursor]];
	} else {
		[self addCursorRect:rightFilterBoundaryRect 
					 cursor:[NSCursor resizeLeftRightCursor]];
		[self addCursorRect:leftFilterBoundaryRect 
					 cursor:[NSCursor resizeLeftRightCursor]];
		if([windowController transceiver].subEnabled == YES) {
			subFilterHotRect = NSMakeRect(NSMinX(subFilterRect) + 3, 
												 NSMinY(subFilterRect),
												 NSWidth(subFilterRect) - 6, 
												 NSHeight(subFilterRect));
			subFilterHotRect = NSRectFromCGRect([tickLayer convertRect:NSRectToCGRect(subFilterHotRect)
											  toLayer:rootLayer]);
			
			[self addCursorRect:subFilterHotRect 
						 cursor:[NSCursor openHandCursor]];
			[self addCursorRect:rightSubFilterBoundaryRect
						 cursor:[NSCursor resizeLeftRightCursor]];
			[self addCursorRect:leftSubFilterBoundaryRect 
						 cursor:[NSCursor resizeLeftRightCursor]];
		}
	} 
}

-(id)actionForLayer:(CALayer *)theLayer forKey:(NSString *) aKey {	
	return [NSNull null];
}

-(BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
    return [NSApp isActive];
}

-(void)setHighLevel:(float)newHighLevel {
    highLevel = newHighLevel;
    [waveLayer setHighLevel:highLevel];
    [[NSUserDefaults standardUserDefaults] setFloat:highLevel forKey:@"highPanLevel"];
    
    [tickLayer setNeedsDisplay];
}

-(void)setLowLevel:(float)newLowLevel {
    lowLevel = newLowLevel;
    [waveLayer setLowLevel:lowLevel];
    [[NSUserDefaults standardUserDefaults] setFloat:lowLevel forKey:@"lowPanLevel"];
    
    [tickLayer setNeedsDisplay];
}

@end

@implementation XTPanadapterLayer

@synthesize dataMUX;
@synthesize highLevel;
@synthesize lowLevel;

-(id)init {
	self = [super init];
	if(self) {		
	}
	
	return self;
}

-(void)drawInCGLContext:(CGLContextObj)ctx 
			pixelFormat:(CGLPixelFormatObj)pf 
		   forLayerTime:(CFTimeInterval)t 
			displayTime:(const CVTimeStamp *)ts {
	
    float *vertices;
	float negativeLowPanLevel;
	
	if(dataMUX == NULL) return;
    
    if(glIsBuffer(vertexBuffer) == GL_FALSE) {
        glGenBuffers(1, &vertexBuffer);
        glBindBufferARB(GL_ARRAY_BUFFER_ARB, vertexBuffer);
    }
	
	NSData *panData = [dataMUX smoothBufferData];
	const float *smoothBuffer = [panData bytes];
    int numSamples = [panData length] / sizeof(float);
    vertices = malloc([panData length] * 2);
	
    //  Fill vector array with Y values
	negativeLowPanLevel = -lowLevel;
	vDSP_vsadd((float *) smoothBuffer, 1, &negativeLowPanLevel, &vertices[1], 2, numSamples);
	
	float range = highLevel - lowLevel;
	vDSP_vsdiv(&vertices[1], 2, &range, &vertices[1], 2, numSamples);
    
    //  Generate X values
    float zero = 0.0f;
    float increment = 1.0f / numSamples;
    vDSP_vramp(&zero, &increment, vertices, 2, numSamples);
	
	glClearColor(0, 0, 0, 0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glViewport(0, 0, (GLsizei) CGRectGetWidth(self.bounds), (GLsizei) CGRectGetHeight(self.bounds));
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluOrtho2D(0.0, (GLdouble) CGRectGetWidth(self.bounds), 0.0, (GLdouble) CGRectGetHeight(self.bounds));
    
	glPushMatrix();
	glScalef(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds), 1.0);
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_LINE_SMOOTH);
	glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
	glDepthMask(GL_FALSE);
	glShadeModel(GL_SMOOTH);
	
	GLfloat lineSizes[2];
	GLfloat lineStep;
	glGetFloatv(GL_LINE_WIDTH_RANGE, lineSizes);
	glGetFloatv(GL_LINE_WIDTH_GRANULARITY, &lineStep);
	glLineWidth(lineSizes[0] + (lineStep * 5));
	glColor4f(0.0, 0.0, 0.0, 1.0);
	
    //  Draw the line from the vertex array
    glEnableClientState(GL_VERTEX_ARRAY);
    glBufferDataARB(GL_ARRAY_BUFFER_ARB, [panData length] * 2, vertices, GL_STREAM_DRAW_ARB);
    glVertexPointer(2, GL_FLOAT, 0, 0);
    glDrawArrays(GL_LINE_STRIP, 0, numSamples);
    glDisableClientState(GL_VERTEX_ARRAY);
	
	glDepthMask(GL_TRUE);
	glDisable(GL_LINE_SMOOTH);
	glDisable(GL_BLEND);
	
	glPopMatrix();
	glFlush();	
	
    free(vertices);
}

-(id)actionForLayer:(CALayer *)theLayer forKey:(NSString *) aKey {	
	return [NSNull null];
}

@end
