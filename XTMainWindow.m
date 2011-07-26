//
//  XTMainWindow.m
//  MacHPSDR
//
//  Copyright (c) 2010 - Jeremy C. McDermond (NH6Z)
//  Copyright (c) 2010 - John James (K1YM)

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

#import "XTMainWindow.h"

#import "TransceiverController.h"


@implementation XTMainWindow

-(void)keyDown:(NSEvent *) theEvent {
	unsigned int modFlags = [theEvent modifierFlags];
	long code = [theEvent keyCode];
	
	int frequencyIncrement = modFlags & NSShiftKeyMask ? 100 : 10;
	
	if (modFlags & NSAlternateKeyMask) {
		if(transceiver.subEnabled == TRUE) {
			switch(code) {
				case 123://<-
					transceiver.subFrequency -= frequencyIncrement;
					break;
					
				case 124://->
					transceiver.subFrequency += frequencyIncrement;
					break;
			}
		}
		return;
	} 	
	
	switch(code) {
		case 123://<-
			transceiver.frequency -= frequencyIncrement;
			break;
			
		case 124://->
			transceiver.frequency += frequencyIncrement;
			break;
	}
} 

-(void)awakeFromNib {
}

-(int)selectedTab {
	return [graphicalDisplayView indexOfTabViewItem: [graphicalDisplayView selectedTabViewItem]];
}

-(void)setSelectedTab: (int) tab {
	[graphicalDisplayView selectTabViewItemAtIndex: tab];
}

@end
