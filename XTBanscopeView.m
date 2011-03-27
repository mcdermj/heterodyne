//
//  XTBanscopeView.m
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

#import "XTBanscopeView.h"

#import "TransceiverController.h"
#import "XTWorkerThread.h"
#import "XTHeterodyneHardwareDriver.h"

@implementation XTBanscopeView

@synthesize highBandscopeLevel;
@synthesize lowBandscopeLevel;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        background = [[NSBezierPath alloc] init];
		mainFrequency = [[NSBezierPath alloc] init];
		path = [[NSBezierPath alloc] init];
		[mainFrequency setLineWidth:0.5];
		[path setLineWidth:0.5];
		
		bandAreas = [NSMutableArray arrayWithCapacity:0];
		
		averageSmoothing = 0.4f;
		
		tickMarks = [[NSMutableArray alloc] init];
		textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor lightGrayColor], NSForegroundColorAttributeName,
						  [NSFont fontWithName:@"Monaco" size:9.0], NSFontAttributeName,
						  nil];
		startFrequency = 0.0;
		endFrequency = 61440000.0;
		
		lowBandscopeLevel = -20.0;
		highBandscopeLevel = 20.0;
		
		// Set up the FFT
		blackmanHarris = [self blackmanHarrisFilter: 4096];
		
		fftSetup = vDSP_create_fftsetup(12, kFFTRadix2);
		
		// Set up some memory
		fftIn.imagp = malloc(2048 * sizeof(float));
		fftIn.realp = malloc(2048 * sizeof(float));
		fftOut = malloc(4096 * sizeof(float));
		results = malloc(2048 * sizeof(float));
		average = malloc(2048 * sizeof(float));
		smoothed = malloc(2048 * sizeof(float));
		y = malloc(2048 * sizeof(float));
		
		[[NSNotificationCenter defaultCenter] addObserver:self
											   selector:@selector(doBoundsChanged:) 
												  name:NSViewBoundsDidChangeNotification 
												  object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
											   selector:@selector(doBoundsChanged:) 
												  name:NSViewFrameDidChangeNotification 
												  object:nil];				
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(doDefaultsNotification:)
													 name:NSUserDefaultsDidChangeNotification
												   object:nil];
		initAverage = YES;
		
		rootLayer = [CALayer layer];
		[rootLayer contentsAreFlipped];
		[self setLayer: rootLayer];
		[self setWantsLayer:YES];
		[rootLayer setDelegate: self];
		rootLayer.frame = NSRectToCGRect(self.frame);			
    }
    return self;
}

-(void) awakeFromNib {	
	[controller addObserver:self forKeyPath:@"frequency" options:NSKeyValueObservingOptionNew context: NULL];
	
	self.lowBandscopeLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"lowBandscopeLevel"];
	self.highBandscopeLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"highBandscopeLevel"];
	
	[self doBoundsChanged:nil];
	[self calculateTickMarks];
	
	[self.window makeFirstResponder:self];
	
	[rootLayer setNeedsDisplay];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataReady) name:@"XTBandscopeDataReady" object: interface];
}

-(void)calculateTickMarks {
	float mark, position;
	NSBezierPath *tickMark;
	
	@synchronized(tickMarks) {
		[tickMarks removeAllObjects];
		
		for(mark = ceilf(startFrequency / 5000000.0) * 5000000.0; mark < endFrequency; mark += 5000000.0) {
			position = (mark - startFrequency) / hzPerUnit;
			
			tickMark = [[NSBezierPath alloc] init];
			[tickMark setLineWidth: 0.5];
			[tickMark moveToPoint: NSMakePoint(position, 0)];
			[tickMark lineToPoint: NSMakePoint(position, height)];
			[tickMarks addObject:[NSArray arrayWithObjects: tickMark, 
								  [NSString stringWithFormat:@"%d", (int) (mark / 1000000.0)], 
								  [NSValue valueWithPoint: NSMakePoint(position + 4, self.frame.size.height - 15)],
								  nil]];
		}	
		
		for(mark = ceilf(lowBandscopeLevel / 10.0) * 10.0; mark < highBandscopeLevel; mark += 10.0) {
			position = (mark - lowBandscopeLevel) * slope;
			
			tickMark = [[NSBezierPath alloc] init];
			[tickMark setLineWidth: 0.5];
			[tickMark moveToPoint: NSMakePoint(0, position)];
			[tickMark lineToPoint: NSMakePoint(width, position)];
			[tickMarks addObject:[NSArray arrayWithObjects: tickMark, 
								  [NSString stringWithFormat:@"%d dB", (int) mark],
								  [NSValue valueWithPoint: NSMakePoint(4, position - 15)], 
								  nil]];			
		}
	}
}	

-(void)doBoundsChanged: (NSNotification *)theNotification {
	[background removeAllPoints];
	[background appendBezierPathWithRect:[self bounds]];
	
	width = self.frame.size.width;
	height = self.frame.size.height;
	hzPerUnit = (float) (endFrequency - startFrequency) / width;
	scale = width / 2047;
	slope = height / (highBandscopeLevel - lowBandscopeLevel);
	xCenter = width / 2;
	
	mainPosition = (controller.frequency - startFrequency) / hzPerUnit;
	[mainFrequency removeAllPoints];
	[mainFrequency moveToPoint:NSMakePoint(mainPosition, 0)];
	[mainFrequency lineToPoint:NSMakePoint(mainPosition, height)];
	
	// Populate the band areas array
	@synchronized(bandAreas) {
		NSDictionary *bandPlan = [controller bandPlan];
		[bandAreas removeAllObjects];
		for(id band in bandPlan) {
			int start = [[[bandPlan objectForKey:band] objectForKey:@"start"] intValue];
			int length = [[[bandPlan objectForKey:band] objectForKey:@"end"] intValue] - start;
			NSBezierPath *bandPath = [[NSBezierPath alloc] init];
			[bandPath appendBezierPathWithRect:NSMakeRect((start - startFrequency) / hzPerUnit, 0, length / hzPerUnit, height)];
			[bandAreas addObject:bandPath];
		}
	}
		
	[self calculateTickMarks];
}

-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
	NSGraphicsContext *nsGraphicsContext;
	nsGraphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:ctx flipped: NO];
	
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:nsGraphicsContext];
	
	// Clear the window
	[[NSColor whiteColor] set];
	[background fill];
	
	// Draw the band plan areas
	@synchronized(bandAreas) {
		for(NSBezierPath *bandArea in bandAreas) {
			[[NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:0.10] set];
			[bandArea fill];
		}
	}
		
	// Draw the main receiver frequency
	[[NSColor redColor] set];
	[mainFrequency stroke];
		
	@synchronized(tickMarks) {
		// Draw the tick marks
		[[NSColor lightGrayColor] set];
		for(NSArray *tickMark in tickMarks) {
			[[tickMark objectAtIndex: 0] stroke];
			[[tickMark objectAtIndex: 1] drawAtPoint:[[tickMark objectAtIndex:2] pointValue] withAttributes:textAttributes];
		}
	}
	
	[[NSColor blackColor] set];
	[path stroke];
	
	[NSGraphicsContext restoreGraphicsState];
	
}

-(void)calculatePath: (NSData *)bandscopeData {	
	int i, j;
	float x = 0;
				
	[path removeAllPoints];
		
	const char *buffer = [bandscopeData bytes];
	
	for(i = 0, j = 0; i < 2048; i++) {
		fftIn.realp[i] = (((float) ((buffer[2 * j] << 8) + buffer[(2 * j) + 1]) / 32768.0f)) * blackmanHarris[j++];
		fftIn.imagp[i] = (((float) ((buffer[2 * j] << 8) + buffer[(2 * j) + 1]) / 32768.0f)) * blackmanHarris[j++];
	}
	
	// Perform the FFT
	vDSP_fft_zrip(fftSetup, &fftIn, 1, 12, kFFTDirection_Forward);
	
	//  The FFT must be scaled by a factor of half (see Apple docs)
	float scaling = 0.5;
	vDSP_vsmul(fftIn.realp, 1, &scaling, fftIn.realp, 1, 2048);
	vDSP_vsmul(fftIn.imagp, 1, &scaling, fftIn.imagp, 1, 2048);
	
	//  Get the squared magnetudes
	vDSP_zvmags(&fftIn, 1, results, 1, 2048);
		
	scaling = 1.0;
	// Convert to dB
	vDSP_vdbcon(results, 1, &scaling, results, 1, 2048, 0);
	
	// If there's not average buffer, copy it in, otherwise calculate average
	if(initAverage == YES) {
		memcpy(average, results, 2048 * sizeof(float));
		initAverage = NO;
	} else {
		scaling = 0.66;
		vDSP_vavlin(results, 1, &averageSmoothing, average, 1, 2048);
	}
	
	// This is linear smoothing without weighted averages.  Get the sliding window sum and divide by the total.
	smoothValue = 3;
	vDSP_vswsum(average, 1, smoothed, 1, 2048, smoothValue);
	vDSP_vsdiv(smoothed, 1, &smoothValue, smoothed, 1, 2048);
	
	// Scale the results to fit in the bandscope.
	negativeLowBandscopeLevel = -lowBandscopeLevel;
	vDSP_vsadd(smoothed, 1, &negativeLowBandscopeLevel, smoothed, 1, 2048);
	vDSP_vsmul(smoothed, 1, &slope, y, 1, 2048);
						
	for(i = 1; i < 2047; ++i) {
		x = i * scale;

		if(i == 1) {
			[path moveToPoint:NSMakePoint(x, y[i])];
		} else {
			[path lineToPoint:NSMakePoint(x, y[i])];
		}
	}
		
	[rootLayer setNeedsDisplay];
	
	[[interface ep4Buffers] freeBuffer:bandscopeData];
	
}

-(void)mouseUp: (NSEvent *)theEvent {
	// Click or Double-Click
	NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView: nil];
	controller.frequency += (clickPoint.x - mainPosition) * hzPerUnit;

}

-(void)scrollWheel:(NSEvent *)theEvent {
	controller.frequency += [theEvent deltaY] * hzPerUnit;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if([keyPath isEqual:@"frequency"]) {		
		mainPosition = (controller.frequency - startFrequency) / hzPerUnit;
		[mainFrequency removeAllPoints];
		[mainFrequency moveToPoint:NSMakePoint(mainPosition, 0)];
		[mainFrequency lineToPoint:NSMakePoint(mainPosition, height)];
		[rootLayer setNeedsDisplay];
	}
}

-(void) dataReady {
	NSData *bandscopeData = [[interface ep4Buffers] getInputBuffer];
	[self performSelector:@selector(calculatePath:) onThread:[controller updateThread] withObject:bandscopeData waitUntilDone:NO];
}

-(void)doDefaultsNotification: (NSNotification *) notification {
	NSString *notificationName = [notification name];
	
	if(notificationName == NSUserDefaultsDidChangeNotification) {
		self.lowBandscopeLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"lowBandscopeLevel"];
		self.highBandscopeLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"highBandscopeLevel"];
		slope = height / (highBandscopeLevel - lowBandscopeLevel);
		[self calculateTickMarks];
	}
}

-(float *) blackmanHarrisFilter: (int) n {
    float* filter;
    float a0=0.35875F,
	a1=0.48829F,
	a2=0.14128F,
	a3=0.01168F;
    float twopi=M_PI*2.0F;
    float fourpi=M_PI*4.0F;
    float sixpi=M_PI*6.0F;
    int i;
	
    filter=malloc(n*sizeof(float));
	
    for(i = 0;i<n;i++) {
        filter[i]=a0
		- a1 * cos(twopi  * (i + 0.5) / n)
		+ a2 * cos(fourpi * (i + 0.5) / n)
		- a3 * cos(sixpi * (i + 0.5) / n);
    }
	
    return filter;
}

-(BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
    return [NSApp isActive];
}

@end
