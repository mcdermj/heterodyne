//
//  XTPanadapterLayer.m
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

#import "XTPanadapterLayer.h"

#include <Accelerate/Accelerate.h>

#include <OpenGL/gl.h>
#include <OpenGL/glu.h>

@implementation XTPanadapterLayer

@synthesize dataMUX;

-(id)init {
	self = [super init];
	if(self) {
		lowPanLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"lowPanLevel"];
		highPanLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"highPanLevel"];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector: @selector(doDefaultsNotification:) 
													 name: NSUserDefaultsDidChangeNotification 
												   object: nil];				
	}
	
	return self;
}

/*
-(CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)mask {
	CGLPixelFormatAttribute attributes[] =
	{
		kCGLPFADisplayMask, mask,
		kCGLPFAAccelerated,
		kCGLPFAColorSize, 24,
		kCGLPFAAlphaSize, 8,
		kCGLPFADepthSize, 16,
		kCGLPFANoRecovery,
		kCGLPFAMultisample,
		kCGLPFASupersample,
		kCGLPFASampleAlpha,
		kCGLPFASamples, 2,
		kCGLPFASampleBuffers, 1,
		0
	};
	
	CGLPixelFormatObj pixelFormatObj = NULL;
	GLint numPixelFormats = 0;
	CGLChoosePixelFormat(attributes, &pixelFormatObj, &numPixelFormats);
	if(pixelFormatObj == NULL) {
		NSLog(@"[XTPanadapterLayer copyCGLPixelFormatForDisplayMask]: Couldn't get a pixel format\n");
	}
	return pixelFormatObj;
}

-(void)releaseCGLPixelFormat:(CGLPixelFormatObj)pixelFormat {
	CGLDestroyPixelFormat(pixelFormat);
} */


-(void)drawInCGLContext:(CGLContextObj)ctx 
			pixelFormat:(CGLPixelFormatObj)pf 
		   forLayerTime:(CFTimeInterval)t 
			displayTime:(const CVTimeStamp *)ts {
	
	float *y;
	float negativeLowPanLevel;
	int i;
	
	if(dataMUX == NULL) return;
	
	NSData *panData = [dataMUX smoothBufferData];
	const float *smoothBuffer = [panData bytes];
	y = malloc([panData length]);
	
	negativeLowPanLevel = -lowPanLevel;
	vDSP_vsadd((float *) smoothBuffer, 1, &negativeLowPanLevel, y, 1, [panData length] / sizeof(float));
	
	float range = highPanLevel - lowPanLevel;
	vDSP_vsdiv(y, 1, &range, y, 1, [panData length] / sizeof(float));
	
	glClearColor(0, 0, 0, 0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glViewport(0, 0, (GLsizei) CGRectGetWidth(self.bounds), (GLsizei) CGRectGetHeight(self.bounds));
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluOrtho2D(0.0, (GLdouble) CGRectGetWidth(self.bounds), 0.0, (GLdouble) CGRectGetHeight(self.bounds));

	glPushMatrix();
	glScalef(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds), 1.0);
	
	int numSamples = [panData length] / sizeof(float);
	
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
	
	glBegin(GL_LINE_STRIP);
	for(i = 0; i < numSamples; ++i) {
		glVertex2f((GLfloat) i / (GLfloat) numSamples, y[i]);
	}
	glEnd();
	
	glDepthMask(GL_TRUE);
	glDisable(GL_LINE_SMOOTH);
	glDisable(GL_BLEND);
	
	glPopMatrix();
	glFlush();	
	
	free(y);
}

-(void)doDefaultsNotification: (NSNotification *) notification {
	NSString *notificationName = [notification name];
	
	if(notificationName == NSUserDefaultsDidChangeNotification ) {
		lowPanLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"lowPanLevel"];
		highPanLevel = [[NSUserDefaults standardUserDefaults] floatForKey:@"highPanLevel"];
	}
}

-(id)actionForLayer:(CALayer *)theLayer forKey:(NSString *) aKey {	
	return [NSNull null];
}

@end
