//
//  AboutBoxView.m
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

#import "AboutBoxView.h"


@implementation AboutBoxView

-(id)infoValueForKey:(NSString*)key
{
    if ([[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:key])
        return [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:key];
	
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:key];
}

- (void)drawRect:(NSRect)rect
{
    [super drawRect: rect];
	
	NSMutableString *versionString = [NSString stringWithFormat: @"Version %@ (%@)", 
									  [self infoValueForKey:@"CFBundleShortVersionString"], 
									  [self infoValueForKey:@"CFBundleVersion"]];
		
    NSTextField *field = [self viewWithTag: 2];
    [field setStringValue: versionString];
	
    // draw the app's icon
    NSImage* iconImage = nil;
    NSImageView* imageView = [self viewWithTag: 1];
    NSString* iconFileStr = [self infoValueForKey:@"CFBundleIconFile"];
    if ([iconFileStr length] > 0)
    {
        // we have a real icon
        iconImage = [NSImage imageNamed: iconFileStr];
    }
    else
    {
        // no particular app icon defined, use the default system icon
        iconImage = [NSImage imageNamed: @"NSApplicationIcon"];
    }
    [imageView setImage: iconImage];	
}


@end
