//
//  XTImageTextCell.m
//  Heterodyne
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

#import "XTImageTextCell.h"
#import "XTHeterodyneHardwareDriver.h"

@implementation XTImageTextCell

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	[self setTextColor:[NSColor blackColor]];
	 
	 NSObject *data = [self objectValue];
		 
	 NSColor *primaryColor = [self isHighlighted] ? [NSColor alternateSelectedControlTextColor] : [NSColor textColor];
	 NSString *primaryText = [data name];
	 
	 NSDictionary *primaryTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys: primaryColor, NSForegroundColorAttributeName,
											[NSFont systemFontOfSize:13], NSFontAttributeName, nil];
	 [primaryText drawAtPoint:NSMakePoint(cellFrame.origin.x+cellFrame.size.height+10, cellFrame.origin.y) 
			   withAttributes:primaryTextAttributes];
	 
	 NSColor *secondaryColor = [self isHighlighted] ? [NSColor alternateSelectedControlTextColor] : [NSColor disabledControlTextColor];
	 NSString *secondaryText = [data versionString];
	 
	 NSDictionary *secondaryTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys: secondaryColor, NSForegroundColorAttributeName, 
											  [NSFont systemFontOfSize:10], NSFontAttributeName, nil];
	 [secondaryText drawAtPoint:NSMakePoint(cellFrame.origin.x+cellFrame.size.height+10, cellFrame.origin.y+cellFrame.size.height/2) 
				 withAttributes:secondaryTextAttributes];
	 
	 [[NSGraphicsContext currentContext] saveGraphicsState];
	 float yOffset = cellFrame.origin.y;
	 if([controlView isFlipped]) {
		 NSAffineTransform *xform = [NSAffineTransform transform];
		 [xform translateXBy:0.0 yBy: cellFrame.size.height];
		 [xform scaleXBy:1.0 yBy:-1.0];
		 [xform concat];
		 yOffset = 0 - cellFrame.origin.y;
	 }
	 
	 NSImage *icon = [data icon];
	 NSImageInterpolation interpolation = [[NSGraphicsContext currentContext] imageInterpolation];
	 [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	 
	 [icon drawInRect:NSMakeRect(cellFrame.origin.x+5, yOffset + 3, cellFrame.size.height - 6, cellFrame.size.height - 6)
			 fromRect:NSMakeRect(0, 0, [icon size].width, [icon size].height)
			operation:NSCompositeSourceOver 
			 fraction:1.0];
	 
	 [[NSGraphicsContext currentContext] setImageInterpolation: interpolation];
	 [[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end
