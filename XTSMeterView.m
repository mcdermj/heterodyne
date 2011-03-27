//
//  XTSMeter.m
//  XTSMeterTest
//
//  Created by Jeremy McDermond on 3/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "XTSMeterView.h"


@implementation XTSMeterView

@synthesize signal;

+(void)initialize {
    [self exposeBinding:@"needlePos"];
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        // Initialization code here.
        
        sweep = 114.0;
        
    }
    
    return self;
}

-(void) drawScale {
    NSBezierPath *scalePath = [NSBezierPath bezierPath];
    NSBezierPath *overPath = [NSBezierPath bezierPath];

    CGFloat midX = NSMidX([self bounds]);
    
    NSPoint pivotPoint = NSMakePoint(midX, 10);
    CGFloat height = NSHeight([self bounds]);
    CGFloat needleLength = fmax(height - 20.0f, midX - 10.0f);


    [scalePath setLineWidth:2.0];
    CGFloat startSweep = 90.0f + (sweep / 2.0f);
    [scalePath appendBezierPathWithArcWithCenter:pivotPoint 
                                          radius:needleLength - 10.0f 
                                      startAngle:startSweep 
                                        endAngle: startSweep - 54
                                       clockwise:YES];
    
    [scalePath setLineWidth: 1.0];
    //NSFont *courier = [NSFont fontWithName:@"Courier" size:8.0];
    for(int i = 0; i < 10; ++i) {
        float tickRads = ((sweep / 2.0f) - (float) (i * 6)) * M_PI / 180.0f;

        [scalePath moveToPoint:NSMakePoint(midX, 10)];
        [scalePath relativeMoveToPoint:NSMakePoint(-sinf(tickRads) * (needleLength - 12.5), cosf(tickRads) * (needleLength - 12.5))];
        [scalePath relativeLineToPoint:NSMakePoint(-sinf(tickRads) * 5, cosf(tickRads) * 5)];
        [scalePath relativeMoveToPoint:NSMakePoint(-sinf(tickRads) * 5, cosf(tickRads) * 5)];
        //[scalePath appendBezierPathWithGlyph:[courier glyphWithName:[NSString stringWithFormat:@"%d", i / 10]] inFont:courier];
    }
    
    
    [scalePath stroke];
    
    [[NSColor redColor] setStroke];
    
    [overPath appendBezierPathWithArcWithCenter:pivotPoint 
                                          radius:needleLength - 10.0f 
                                      startAngle:startSweep - 54 
                                        endAngle: startSweep - sweep
                                       clockwise:YES];

    
    for(int i = 7; i < 12; ++i) {
        float tickRads = ((sweep / 2.0f) - (float) (i * 10)) * M_PI / 180.0f;
        
        [overPath moveToPoint:NSMakePoint(midX, 10)];
        [overPath relativeMoveToPoint:NSMakePoint(-sinf(tickRads) * (needleLength - 12.5), cosf(tickRads) * (needleLength - 12.5))];
        [overPath relativeLineToPoint:NSMakePoint(-sinf(tickRads) * 5, cosf(tickRads) * 5)];
        [overPath relativeMoveToPoint:NSMakePoint(-sinf(tickRads) * 5, cosf(tickRads) * 5)];
        //[scalePath appendBezierPathWithGlyph:[courier glyphWithName:[NSString stringWithFormat:@"%d", i / 10]] inFont:courier];
    }
    
    [overPath stroke];

}

-(void) drawRect:(NSRect)dirtyRect {
    
    
    NSBezierPath *needlePath = [NSBezierPath bezierPath];
        
    float needleRads = ((sweep / 2.0f) - needlePos) * M_PI / 180.0f;
    
    [[NSColor whiteColor] setFill];
    
    [NSBezierPath fillRect:[self bounds]];
    [NSBezierPath strokeRect:[self bounds]];
    
    CGFloat midX = NSMidX([self bounds]);
    
    CGFloat height = NSHeight([self bounds]);
    CGFloat needleLength = fmax(height - 20.0f, midX - 10.0f);
        
    [needlePath setLineWidth: 0.5];
    [needlePath moveToPoint:NSMakePoint(midX, 10)];
    [needlePath relativeLineToPoint:NSMakePoint(-sinf(needleRads) * needleLength, cosf(needleRads) * needleLength)];
    [needlePath stroke];
    
    [self drawScale];
}

-(void)setNeedlePos:(float)theNeedlePos {
    needlePos = theNeedlePos;
    [self setNeedsDisplay:YES];
}

-(void)setSignal:(float)theValue {
    float lowValue = -121.0;
    float highValue = -7.0;
    
    theValue = theValue < lowValue ? lowValue : theValue;
    theValue = theValue > highValue ? highValue : theValue;
    
    float span = highValue - lowValue;
    float scaledValue = 1.0 + (theValue / span);
    
    [self setNeedlePos:scaledValue * sweep];
}

-(float)needlePos {
    return needlePos;
}

- (void)dealloc
{
    [super dealloc];
}

@end
