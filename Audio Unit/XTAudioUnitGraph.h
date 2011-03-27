//
//  XTAudioUnitGraph.h
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

#import <Cocoa/Cocoa.h>

#include <CoreAudio/CoreAudio.h>
#include <AudioToolbox/AudioToolbox.h>

@class XTAudioUnitNode;

@interface XTAudioUnitGraph : NSObject {
	
	AUGraph theGraph;
	NSMutableArray *nodeArray;

}

-(OSStatus)open;
-(OSStatus)initialize;
-(OSStatus)start;
-(OSStatus)stop;
-(OSStatus)close;
-(OSStatus)update;

-(XTAudioUnitNode *)addNodeWithType:(OSType)type subType:(OSType)subType andManufacturer:(OSType)manufacturer;
-(XTAudioUnitNode *)addDefaultOutputUnit;
-(XTAudioUnitNode *)addOutputUnit;

-(void)connectNodes;
-(NSArray *)nodes;

@property (readonly) AUGraph graph;

@end
