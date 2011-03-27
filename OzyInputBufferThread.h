//
//  OzyInputBufferThread.h
//  MacHPSDR
//
//  Created by Jeremy McDermond on 2/13/10.
//  Copyright 2010 net.nh6z. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "OzyInputBuffers.h"
#import "OzyInterface.h"

@interface OzyInputBufferThread : NSThread {
	OzyInterface	*interface;
}

-(id) initWithInterface:(OzyInterface *)_interface;
-(void) main;

@end
