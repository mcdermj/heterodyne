//
//  XTAudioUnitGraph.m
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

#import "XTAudioUnitGraph.h"
#import "XTAudioUnitNode.h"
#import "XTAudioUnit.h"

@implementation XTAudioUnitGraph

-(id)init {
	self = [super init];
	
	if(self) {
		if(NewAUGraph(&theGraph) != noErr) {
			return nil;
		}
		nodeArray = [[NSMutableArray alloc] init];
	}
	
	return self;
}

-(AUGraph) graph {
	return theGraph;
}

-(OSStatus)open {
	return AUGraphOpen(theGraph);
}

-(OSStatus)initialize {
	return AUGraphInitialize(theGraph);
}

-(OSStatus)start {
	return AUGraphStart(theGraph);
}

-(OSStatus)stop {
	return AUGraphStop(theGraph);
}

-(OSStatus)close {
	return AUGraphClose(theGraph);
}

-(OSStatus)update {
	Boolean isUpdated;
	
	return AUGraphUpdate(theGraph, &isUpdated);
}

-(XTAudioUnitNode *)addNodeWithType:(OSType)type subType:(OSType)subType andManufacturer:(OSType)manufacturer {
	AudioComponentDescription componentDescription;
	OSStatus error;
	
	componentDescription.componentType = type;
	componentDescription.componentSubType = subType;
	componentDescription.componentManufacturer = manufacturer;
	componentDescription.componentFlags = 0;
	componentDescription.componentFlagsMask = 0;
	
	XTAudioUnitNode *newNode = [[XTAudioUnitNode alloc] initWithGraph:self];
	
	error = AUGraphAddNode(theGraph, &componentDescription, [newNode node]);
	
	if(error == noErr) {
		[nodeArray addObject:newNode];
		return newNode;
	}
	
	NSLog(@"%@:%s Error adding node: %s\n", [self class], (char *) _cmd, GetMacOSStatusErrorString(error));
	return nil;
}

-(XTAudioUnitNode *)addDefaultOutputUnit {
	return [self addNodeWithType:kAudioUnitType_Output subType:kAudioUnitSubType_DefaultOutput andManufacturer:kAudioUnitManufacturer_Apple];
}

-(XTAudioUnitNode *)addOutputUnit {
	return [self addNodeWithType:kAudioUnitType_Output subType:kAudioUnitSubType_HALOutput andManufacturer:kAudioUnitManufacturer_Apple];
}



//  XXX This should return something useful on error
-(void)connectNodes {
	[nodeArray enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
		if(idx < [nodeArray count] - 1) {
			XTAudioUnitNode *thisNode = (XTAudioUnitNode *) obj;
			XTAudioUnitNode *nextNode = [nodeArray objectAtIndex:idx + 1];
			[thisNode connectOutputTo:nextNode];
		}
	}];
}

-(NSArray *)nodes {
	return [NSArray arrayWithArray:nodeArray];
}

@end
