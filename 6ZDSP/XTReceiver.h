//
//  XTReceiver.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 4/19/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XTWorkerThread;
@class XTDSPBlock;

@interface XTReceiver : NSObject {
@private
    
    NSMutableArray *dspModules;
    XTWorkerThread *workerThread;
    XTDSPBlock *results;
    
    float sampleRate;
    
}

@property float sampleRate;
@property float frequency;
@property float highCut;
@property float lowCut;
@property (readonly) XTDSPBlock *results;

-(void)processComplexSamples:(XTDSPBlock *)complexData withCompletionSelector:(SEL)completion onObject:(id)callbackObject;
-(id)initWithSampleRate:(float)sampleRate;

@end
