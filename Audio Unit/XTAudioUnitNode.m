//
//  XTAudioUnitNode.m
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

#import "XTAudioUnitNode.h"
#import "XTAudioUnitGraph.h"
#import "XTAudioUnit.h"

@implementation XTAudioUnitNode

-(id)initWithGraph:(XTAudioUnitGraph *)graph {
	self = [super init];
	
	if(self) {
		theGraph = graph;
	}
	
	return self;
}

-(AUNode *) node {
	return &theNode;
}

-(XTAudioUnit *) unit {
	XTAudioUnit *theUnit = [[XTAudioUnit alloc] init];
	
	AUGraphNodeInfo([theGraph graph], theNode, NULL, [theUnit unit]);
	return theUnit;
}

-(OSStatus)connectInputTo:(XTAudioUnitNode *)node {
	return AUGraphConnectNodeInput([theGraph graph], *[node node], 0, theNode, 0);
}

-(OSStatus)connectOutputTo:(XTAudioUnitNode *)node {
	return AUGraphConnectNodeInput([theGraph graph], theNode, 0, *[node node], 0);
}

-(OSStatus)connectOutputNumber: (UInt32)output To:(XTAudioUnitNode *) node {
	return AUGraphConnectNodeInput([theGraph graph], theNode, output, *[node node], 0);
}

@end
