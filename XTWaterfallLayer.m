//
//  XTWaterfallLayer.m
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

// $Id:$

#import "XTWaterfallLayer.h"

#include <OpenGL/gl.h>
#include <OpenGL/glu.h>


@implementation XTWaterfallLayer

@synthesize dataMUX;
@synthesize flowsUp;

-(id)init {
	self = [super init];
	
	if(self) {
		int i;
		NSGradient *colorGradient = [NSGradient alloc];
		[colorGradient initWithColorsAndLocations:[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:0.0], 0.0, 
		 [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:1.0 alpha:1.0], (2.0f/9.0f),
		 [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:1.0 alpha:1.0], (3.0f/9.0f),
		 [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:0.0 alpha:1.0], (4.0f/9.0f),
		 [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:0.0 alpha:1.0], (5.0f/9.0f),
		 [NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:1.0], (7.0f/9.0f),
		 [NSColor colorWithCalibratedRed:1.0 green:0.0 blue:1.0 alpha:1.0], (8.0f/9.0f),
		 [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0], 1.0,
		 nil];
		
		for(i = 0; i < 20000; ++i) {
			float location = ((float) i) / 20000.0;
			CGFloat r, g, b, alpha;
			[[[colorGradient interpolatedColorAtLocation:location] colorUsingColorSpaceName: NSDeviceRGBColorSpace] getRed:&r 
																													 green:&g 
																													  blue:&b
																													 alpha:&alpha];
			
			colorGradientArray[i] = ( (int)(b*255.5) ) + ( (int)(g*255.5) << 8 ) + ( (int)(r*255.5) << 16 ) + 0xFF000000;
		}

		lowWaterLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"lowWaterLevel"];
        negLowWat = -lowWaterLevel;
		highWaterLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"highWaterLevel"];
        scale = 20000.0f / (highWaterLevel - lowWaterLevel);
	
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector: @selector(doDefaultsNotification:) 
													 name: NSUserDefaultsDidChangeNotification 
												   object: nil];				
		
		currentLine = 0;
		flowsUp = NO;
        
        high = 19999.0;
        low = 0.0;
        
        autoScale = YES;
	}
	
	return self;
}
	

-(void)drawInCGLContext:(CGLContextObj)glContext
			pixelFormat:(CGLPixelFormatObj)pixelFormat 
		   forLayerTime:(CFTimeInterval)timeInterval
			displayTime:(const CVTimeStamp *)timeStamp {
		
	if(dataMUX == NULL) return;
    
    if(autoScale) {
        memcpy(sortBuffer, [[dataMUX smoothBufferData] bytes], sizeof(sortBuffer));
        vDSP_vsort(sortBuffer, SPECTRUM_BUFFER_SIZE, 1);
        negLowWat = -sortBuffer[1024];
        
        float denominator = sortBuffer[SPECTRUM_BUFFER_SIZE - 1] - sortBuffer[SPECTRUM_BUFFER_SIZE / 4];
        scale = denominator == 0 ? 0 : 20000.0f / denominator;
        
        //scale = 20000.0f / ((sortBuffer[SPECTRUM_BUFFER_SIZE - 1] == 0 ? 1 : sortBuffer[SPECTRUM_BUFFER_SIZE - 1]) - sortBuffer[SPECTRUM_BUFFER_SIZE / 4]);
        //scale = isnan(scale) || isinf(scale) ? 0 : scale;
    }
	    
    vDSP_vsadd((float *) [[dataMUX smoothBufferData] bytes], 1, &negLowWat, intensityBuffer, 1, SPECTRUM_BUFFER_SIZE);
    vDSP_vsmul(intensityBuffer, 1, &scale, intensityBuffer, 1, SPECTRUM_BUFFER_SIZE);
    vDSP_vclip(intensityBuffer, 1, &low, &high, intensityBuffer, 1, SPECTRUM_BUFFER_SIZE);
    
	for(int i = 0; i < SPECTRUM_BUFFER_SIZE; i++) 
		line[i] = colorGradientArray[(int) intensityBuffer[i]];
	
	/* glClearColor(0, 0, 0, 0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); */
	
	glViewport(0, 0, (GLsizei) CGRectGetWidth(self.bounds), (GLsizei) CGRectGetHeight(self.bounds));
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluOrtho2D(0.0, (GLdouble) CGRectGetWidth(self.bounds), 0.0, (GLdouble) CGRectGetHeight(self.bounds));
	
	if(glIsTexture(texture) == GL_FALSE) {
		glGenTextures(1, &texture);
		glBindTexture(GL_TEXTURE_2D, texture);
		
		char *blankData = (char *) malloc(WATERFALL_SIZE * 512 * 4);
		memset(blankData, 0, WATERFALL_SIZE * 512 * 4);
	
		glPixelStorei(GL_UNPACK_ROW_LENGTH, WATERFALL_SIZE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WATERFALL_SIZE, 512, 0, GL_RGBA, GL_UNSIGNED_BYTE, blankData);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
	}
	
	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
	
	glPixelStorei(GL_UNPACK_ROW_LENGTH, WATERFALL_SIZE);
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
	
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, currentLine, WATERFALL_SIZE, 1, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, line);
	currentLine = (currentLine + 1) % 512;
	
	glPushMatrix();
	glScalef(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds), 1.0);
	
	glBegin(GL_QUADS);
	{
		float prop_y, off;
		prop_y = (float) currentLine  / 511.0;
		off = 1.0 / 511.0;
		
		if(flowsUp == NO) {
			glTexCoord2f(0, prop_y);
			glVertex2f(0, 0);
			
			glTexCoord2f(1, prop_y);
			glVertex2f(1, 0);
			
			glTexCoord2f(1, prop_y + 1 - off);
			glVertex2f(1, 1);
			
			glTexCoord2f(0, prop_y + 1 - off);
			glVertex2f(0, 1);
		} else {
			glTexCoord2f(0, prop_y);
			glVertex2f(0, 1);
			
			glTexCoord2f(1, prop_y);
			glVertex2f(1, 1);
			
			glTexCoord2f(1, prop_y + 1 - off);
			glVertex2f(1, 0);
			
			glTexCoord2f(0, prop_y + 1 - off);
			glVertex2f(0, 0);
		}
	}
	glEnd();
	glPopMatrix();
	
	glFlush();	
}

-(void)doDefaultsNotification: (NSNotification *) notification {
	NSString *notificationName = [notification name];
	
	if(notificationName == NSUserDefaultsDidChangeNotification ) {
		lowWaterLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"lowWaterLevel"];
        negLowWat = -lowWaterLevel;
		highWaterLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"highWaterLevel"];
        scale = 20000.0f / (highWaterLevel - lowWaterLevel);
	}
}

@end
