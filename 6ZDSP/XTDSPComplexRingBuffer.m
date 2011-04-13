//
//  XTDSPComplexRingBuffer.m
//  Heterodyne
//
//  Created by Jeremy McDermond on 3/29/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import "XTDSPComplexRingBuffer.h"
#import "XTSplitComplexData.h"
#import "XTDSPBlock.h"


@implementation XTDSPComplexRingBuffer

- (id)initWithElements:(int)elements
{
    self = [super init];
    if (self) {
        // Initialization code here.
        buffer = [XTSplitComplexData splitComplexDataWithElements:elements];
        bufferRange = NSMakeRange(0, elements);
        insertRange = NSMakeRange(0, elements);
    }
    
    return self;
}

-(void)insert:(XTDSPBlock *)block {
    insertRange.length = [block blockSize];
    
    NSRange intersectionRange = NSIntersectionRange(bufferRange, insertRange);
    @synchronized(buffer) {
   //     [buffer replaceInRange:intersectionRange with:
    }
}

@end
