//
//  XTDSPComplexRingBuffer.h
//  Heterodyne
//
//  Created by Jeremy McDermond on 3/29/11.
//  Copyright 2011 net.nh6z. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XTDSPSplitComplexData;

@interface XTDSPComplexRingBuffer : NSObject {
@private
    XTDSPSplitComplexData *buffer;
    NSRange bufferRange;
    NSRange insertRange;
    
}

@end
