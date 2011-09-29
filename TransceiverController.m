//
//  TransceiverController.m
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

#import "TransceiverController.h"
#import "XTWorkerThread.h"
#import "XTImageTextCell.h"
#import "XTSMeterView.h"
#import "XTReceiver.h"

#import "XTDTTSP.h"

@implementation TransceiverController

@synthesize interface;
@synthesize meterReading;
@synthesize filterSymmetry;
@synthesize frequency;
@synthesize mode;
@synthesize sampleRate;
@synthesize filterHigh;
@synthesize filterLow;
@synthesize subFilterHigh;
@synthesize subFilterLow;
@synthesize volume;
@synthesize subFrequency;
@synthesize subPan;
@synthesize pan;
@synthesize subVolume;
@synthesize subEnabled;
@synthesize subMeterReading;
@synthesize subMode;
@synthesize noiseReduction;
@synthesize autoNotchFilter;
@synthesize noiseBlanker;
@synthesize binaural;
@synthesize subNoiseReduction;
@synthesize subAutoNotchFilter;
@synthesize subNoiseBlanker;
@synthesize subBinaural;
@synthesize AGC;
@synthesize subAGC;
@synthesize updateThread;
@synthesize preamp;
@synthesize bandPlan;
@synthesize drivers;

+(NSArray *)pluginPaths {
	NSArray *librarySearchPaths;
	NSMutableArray *pluginSearchPaths = [NSMutableArray array];
	NSMutableArray *plugins = [NSMutableArray array];
	
	librarySearchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES);
	for(NSString *path in librarySearchPaths) 
		[pluginSearchPaths addObject:[path stringByAppendingPathComponent:@"Application Support/Heterodyne/PlugIns"]];
	[pluginSearchPaths addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
	
	for(NSString *path in pluginSearchPaths) 
		for(NSString *subPath in [[NSFileManager defaultManager] subpathsAtPath:path]) 
			if([[subPath pathExtension] isEqualToString:@"bundle"]) 
				[plugins addObject:[path stringByAppendingPathComponent:subPath]];
	
	return [NSArray arrayWithArray:plugins];
}

-(id)init {
	self = [super init];
	
	if(self) {
		NSBundle *currentPlugin;
		Class principalClass;
		NSMutableArray *tempDrivers = [NSMutableArray array];
		
		sdr = [[XTDTTSP alloc] init];
		filterCalibrationOffset = 3.0f * (11.0f - log10f(1024.0f));
		preampOffset = -20.0;
		subMeterReading = meterReading = -70.0;
		
		updateThread = [[XTWorkerThread alloc] init];
		[updateThread start];
		
		for(NSString *path in [TransceiverController pluginPaths]) {
			currentPlugin = [NSBundle bundleWithPath:path];
			if(currentPlugin) {
				principalClass = [currentPlugin principalClass];
				if([principalClass conformsToProtocol:@protocol(XTHeterodyneHardwareDriver)]) {
					NSLog(@"Found Hardware Driver: %@\n", [principalClass IDString]);
					[tempDrivers addObject:principalClass];
				}
			}
		}
		drivers = [NSArray arrayWithArray:tempDrivers];
		
		//  Needs to get from defaults
		NSString *savedDriver = [[NSUserDefaults standardUserDefaults] objectForKey:@"activeHardwareDriver"];
		if(savedDriver == nil) {
			NSLog(@"[%@ %s]:  No driver in defaults, selecting first driver discovered\n", [self class], (char *) _cmd);
			currentDriver = 0;
            [[NSUserDefaults standardUserDefaults] setObject:NSStringFromClass([[drivers objectAtIndex:currentDriver] class]) forKey:@"activeHardwareDriver"];
		} else {
			currentDriver = [drivers indexOfObject:NSClassFromString(savedDriver)];
 		}
		
		bandPlan = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"US Bandplan" ofType:@"plist"]];
        
        //  Vend ourself for distributed objects
        NSSocketPort *communicationsPort = [[NSSocketPort alloc] init];
        if(![[NSSocketPortNameServer sharedInstance] registerPort:communicationsPort 
                                                             name:@"Heterodyne"]) {
            NSLog(@"Couldn't register port\n");
        }
        controlConnection = [NSConnection connectionWithReceivePort:communicationsPort sendPort:nil];
        [controlConnection setRootObject:self];
        [controlConnection runInNewThread];
	}
	
	return self;
}

-(void)awakeFromNib {
    
}

-(void)stop {
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:@"XTSampleRateChanged"
												  object:interface];
	[interface stop];
	[meterTimer invalidate];
	[sdr stop];
	
	interface = nil;
}

-(void)setCurrentDriver:(NSIndexSet *)selectionSet {
	int newDriver = [selectionSet firstIndex];
	if( currentDriver == newDriver || newDriver < 0) {
		return;
	}
	
	[self stop];
	currentDriver = newDriver;
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromClass([[drivers objectAtIndex:currentDriver] class]) forKey:@"activeHardwareDriver"];
	[self start];
	
	if(![[[prefsPane contentView] subviews] containsObject:[interface configWindow]]) {
		/*NSView *configWindow = [interface configWindow];
		NSRect viewFrame = [hardwarePreferencesView frame];
		NSRect newFrame = [configWindow frame];
		NSRect windowFrame = [prefsPane frame];
		NSRect contentFrame = [[prefsPane contentView] frame];

		
		NSLog(@"Old View: %f,%f %fx%f\n", viewFrame.origin.x, viewFrame.origin.y, viewFrame.size.width, viewFrame.size.height);
		NSLog(@"New View: %f,%f %fx%f\n", newFrame.origin.x, newFrame.origin.y, newFrame.size.width, newFrame.size.height);
		NSLog(@"Window Frame: %f,%f %fx%f\n", windowFrame.origin.x, windowFrame.origin.y, windowFrame.size.width, windowFrame.size.height);		
		NSLog(@"Content Frame: %f,%f %fx%f\n", contentFrame.origin.x, contentFrame.origin.y, contentFrame.size.width, contentFrame.size.height);		

		
		viewFrame.origin.y = newFrame.origin.y;
		[configWindow setFrameOrigin:viewFrame.origin];
		
		[[hardwarePreferencesView superview] replaceSubview:hardwarePreferencesView with:configWindow];
		hardwarePreferencesView = configWindow;

		NSRect configFrame = [configWindow frame];
		NSLog(@"New View Next: %f,%f %fx%f\n", configFrame.origin.x, configFrame.origin.y, configFrame.size.width, configFrame.size.height);

		
		windowFrame.size.width += newFrame.size.width - viewFrame.size.width;
		windowFrame.size.height += newFrame.size.height - viewFrame.size.height;
		
		contentFrame = [[prefsPane contentView] frame];
		NSLog(@"Content Frame: %f,%f %fx%f\n", contentFrame.origin.x, contentFrame.origin.y, contentFrame.size.width, contentFrame.size.height);		

		
		[prefsPane setFrame:windowFrame display:YES animate:YES];
		
		contentFrame = [[prefsPane contentView] frame];
		NSLog(@"Content Frame: %f,%f %fx%f\n", contentFrame.origin.x, contentFrame.origin.y, contentFrame.size.width, contentFrame.size.height);		

		configFrame = [configWindow frame];
		NSLog(@"New View Next 2: %f,%f %fx%f\n", configFrame.origin.x, configFrame.origin.y, configFrame.size.width, configFrame.size.height);
*/
		NSView *configWindow = [interface configWindow];
		// NSView *contentView = [prefsPane contentView];
		NSRect oldFrame = [hardwarePreferencesView frame];
		// NSRect newBounds = [configWindow bounds];

		
		[[hardwarePreferencesView superview] replaceSubview:hardwarePreferencesView with:configWindow];
		hardwarePreferencesView = configWindow;
		NSRect newFrame = [configWindow frame];
		
		newFrame.origin.x = oldFrame.origin.x;
		newFrame.origin.y = oldFrame.origin.y;
		newFrame.size.width = oldFrame.size.width;
		newFrame.size.height = oldFrame.size.height;
		[configWindow setFrame:newFrame];
		
		NSSize delta = NSMakeSize(newFrame.size.width - oldFrame.size.width, newFrame.size.height - oldFrame.size.height);
		NSRect windowFrame = [prefsPane frame];
		windowFrame.size.height += delta.height;
		windowFrame.size.width += delta.width;
		
		[prefsPane setFrame:windowFrame display:YES animate:YES];

	}	
}

-(NSIndexSet *)currentDriver {
	return [NSIndexSet indexSetWithIndex:currentDriver];
}

-(void)restoreParams {
	[self willChangeValueForKey:@"frequency"];
	frequency = [[NSUserDefaults standardUserDefaults] integerForKey:@"receiverFrequency"];
	[self didChangeValueForKey:@"frequency"];
	
	[self willChangeValueForKey:@"mode"];
	mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"mode"];
	[self didChangeValueForKey:@"mode"];
	
	[self willChangeValueForKey:@"volume"];
	volume = [[NSUserDefaults standardUserDefaults] floatForKey:@"volume"];
	[self didChangeValueForKey:@"volume"];
	
	[self willChangeValueForKey:@"filterHigh"];
	filterHigh = [[NSUserDefaults standardUserDefaults] floatForKey:@"filterHigh"];
	[self didChangeValueForKey:@"filterHigh"];
	
	[self willChangeValueForKey:@"filterLow"];
	filterLow = [[NSUserDefaults standardUserDefaults] floatForKey:@"filterLow"];
	[self didChangeValueForKey:@"filterLow"];
	
	[self willChangeValueForKey:@"filterSymmetry"];
	filterSymmetry = [[NSUserDefaults standardUserDefaults] boolForKey:@"filterSymmetry"];
	[self didChangeValueForKey:@"filterSymmetry"];
	
	[self willChangeValueForKey:@"pan"];
	pan = [[NSUserDefaults standardUserDefaults] floatForKey:@"pan"];
	[self didChangeValueForKey:@"pan"];
	
	[self willChangeValueForKey:@"subFrequency"];
	subFrequency = [[NSUserDefaults standardUserDefaults] integerForKey:@"subFrequency"];
	[self didChangeValueForKey:@"subFrequency"];
	
	[self willChangeValueForKey:@"subVolume"];
	subVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"subVolume"];
	[self didChangeValueForKey:@"subVolume"];
	
	[self willChangeValueForKey:@"subPan"];
	subPan = [[NSUserDefaults standardUserDefaults] floatForKey:@"subPan"];
	[self didChangeValueForKey:@"subPan"];
	
	[self willChangeValueForKey:@"subEnabled"];
	subEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"subEnabled"];
	[self didChangeValueForKey:@"subEnabled"];
	
	[self willChangeValueForKey:@"subFilterHigh"];
	subFilterHigh = [[NSUserDefaults standardUserDefaults] floatForKey:@"subFilterHigh"];
	[self didChangeValueForKey:@"subFilterHigh"];
	
	[self willChangeValueForKey:@"subFilterLow"];
	subFilterLow = [[NSUserDefaults standardUserDefaults] floatForKey:@"subFilterLow"];
	[self didChangeValueForKey:@"subFilterLow"];
	
	[self willChangeValueForKey:@"subMode"];
	subMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"subMode"];
	[self didChangeValueForKey:@"subMode"];
	
	[self willChangeValueForKey:@"AGC"];
	AGC = [[NSUserDefaults standardUserDefaults] integerForKey:@"AGC"];
	[self didChangeValueForKey:@"AGC"];
	
	[self willChangeValueForKey:@"subAGC"];
	subAGC = [[NSUserDefaults standardUserDefaults] integerForKey:@"subAGC"];
	[self didChangeValueForKey:@"subAGC"];
	
	filterList = [[NSUserDefaults standardUserDefaults] objectForKey:@"filterList"];
	[self recalcFilterPresets];
	subFilterList = [[NSUserDefaults standardUserDefaults] objectForKey:@"subFilterList"];
	[self recalcSubFilterPresets];
	
	[self willChangeValueForKey:@"preamp"];
	preamp = [[NSUserDefaults standardUserDefaults] boolForKey:@"preamp"];
	[self didChangeValueForKey:@"preamp"];	
    
    receiverCalibration = [[NSUserDefaults standardUserDefaults] floatForKey:@"receiveCalibrationOffset"];
	
}

-(void)start {
	
	[self restoreParams];
	
	interface = [[[drivers objectAtIndex:currentDriver] alloc] initWithSDR:sdr];
	sampleRate = [interface sampleRate];
	[sdr setSampleRate:sampleRate];
	[sdr start];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(newSampleRate)
												 name:@"XTSampleRateChanged"
											   object: interface];
    [[XTReceiver mainReceiver] setFrequency:(float) frequency];
	[self initDSP];
		
	[NSThread detachNewThreadSelector:@selector(start) toTarget:interface withObject:nil];
	
}


-(void)newSampleRate {
	[self setSampleRate:[interface sampleRate]];
}

-(void)saveParams {
	[[NSUserDefaults standardUserDefaults] setInteger:frequency forKey:@"receiverFrequency"];
	[[NSUserDefaults standardUserDefaults] setInteger:mode forKey:@"mode"];
	[[NSUserDefaults standardUserDefaults] setFloat:volume forKey:@"volume"];
	[[NSUserDefaults standardUserDefaults] setFloat:filterHigh forKey:@"filterHigh"];
	[[NSUserDefaults standardUserDefaults] setFloat:filterLow forKey:@"filterLow"];
	[[NSUserDefaults standardUserDefaults] setBool:filterSymmetry forKey:@"filterSymmetry"];
	[[NSUserDefaults standardUserDefaults] setFloat:pan forKey:@"pan"];
	[[NSUserDefaults standardUserDefaults] setInteger:subFrequency forKey:@"subFrequency"];
	[[NSUserDefaults standardUserDefaults] setFloat:subVolume forKey:@"subVolume"];
	[[NSUserDefaults standardUserDefaults] setFloat:subPan forKey:@"subPan"];
	[[NSUserDefaults standardUserDefaults] setBool:subEnabled forKey:@"subEnabled"];
	[[NSUserDefaults standardUserDefaults] setFloat:subFilterLow forKey:@"subFilterLow"];
	[[NSUserDefaults standardUserDefaults] setFloat:subFilterHigh forKey:@"subFilterHigh"];
	[[NSUserDefaults standardUserDefaults] setInteger:subMode forKey:@"subMode"];
	[[NSUserDefaults standardUserDefaults] setInteger:AGC forKey:@"AGC"];
	[[NSUserDefaults standardUserDefaults] setInteger:subAGC forKey:@"subAGC"];
	[[NSUserDefaults standardUserDefaults] setBool:preamp forKey:@"preamp"];
}

-(IBAction)bandstackPressed: (id) sender {
	NSString *destinationBand = [[sender selectedCell] title];
	
	NSMutableDictionary *bandstackRegisters = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:@"bandstackRegisters"]];
	NSMutableArray *bandRegisters = [NSMutableArray arrayWithArray:[bandstackRegisters objectForKey:destinationBand]];
	
	if([destinationBand isEqualToString:[self band]] == YES) {
		[bandRegisters insertObject:[self saveToDictionary] atIndex:0];
		[self restoreFromDictionary:[bandRegisters lastObject]];
		[bandRegisters removeLastObject];
		[bandstackRegisters setObject:bandRegisters forKey:destinationBand];
		[[NSUserDefaults standardUserDefaults] setObject:bandstackRegisters forKey:@"bandstackRegisters"];
	} else {
		[self restoreFromDictionary:[bandRegisters lastObject]];
	}
}

-(NSString *)band {
	for(id band in bandPlan) {
		if(frequency >= [[[bandPlan objectForKey:band] objectForKey:@"start"] intValue] &&
		   frequency <= [[[bandPlan objectForKey:band] objectForKey:@"end"] intValue]) {
			return band;
		}
	}
	
	return @"GEN";
}

-(NSDictionary *)saveToDictionary {
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:frequency], @"frequency",
			[NSNumber numberWithInt:mode], @"mode",
			[NSNumber numberWithDouble:filterHigh], @"filterHigh",
			[NSNumber numberWithDouble:filterLow], @"filterLow",
			[NSNumber numberWithInt:AGC], @"AGC",
			[NSNumber numberWithBool:subEnabled], @"subEnabled",
			[NSNumber numberWithInt:subFrequency], @"subFrequency",
			[NSNumber numberWithInt:subMode], @"subMode",
			[NSNumber numberWithDouble:subFilterHigh], @"subFilterHigh",
			[NSNumber numberWithDouble:subFilterLow], @"subFilterLow",
			[NSNumber numberWithInt:subAGC], @"subAGC",
			[NSNumber numberWithBool:preamp], @"preamp",
			nil];
}


-(void)restoreFromDictionary:(NSDictionary *) frequencyDictionary {
	self.frequency = [[frequencyDictionary objectForKey:@"frequency"] intValue];
	self.mode = [[frequencyDictionary objectForKey:@"mode"] intValue];
	self.filterHigh = [[frequencyDictionary objectForKey:@"filterHigh"] doubleValue];
	self.filterLow = [[frequencyDictionary objectForKey:@"filterLow"] doubleValue];
	self.AGC = [[frequencyDictionary objectForKey:@"AGC"] intValue];
	
	self.subEnabled = [[frequencyDictionary objectForKey:@"subEnabled"] boolValue];
	self.subFrequency = [[frequencyDictionary objectForKey:@"subFrequency"] intValue];
	self.subMode = [[frequencyDictionary objectForKey:@"subMode"] intValue];
	self.subFilterHigh = [[frequencyDictionary objectForKey:@"subFilterHigh"] doubleValue];
	self.subFilterLow = [[frequencyDictionary objectForKey:@"subFilterLow"] doubleValue];
	self.subAGC = [[frequencyDictionary objectForKey:@"subAGC"] intValue];
	self.preamp = [[frequencyDictionary objectForKey:@"preamp"] boolValue];
}

-(void)refreshParams {
    receiverCalibration = [[NSUserDefaults standardUserDefaults] floatForKey:@"receiveCalibrationOffset"];
}

-(void)setPreamp:(BOOL) preampState {
	[self willChangeValueForKey:@"preamp"];
	[interface setPreamp:preampState];
	preamp = preampState;
	[self didChangeValueForKey:@"preamp"];
}

-(void)setFrequency:(int) theFrequency {
	int diffFrequency;
	
    /*
	[self willChangeValueForKey:@"frequency"];
	frequency = theFrequency;	
	[interface setFrequency:theFrequency forReceiver:0];
	[self didChangeValueForKey:@"frequency"]; */
    
    [[XTReceiver mainReceiver] setFrequency: (float)theFrequency];
	
	diffFrequency = frequency - subFrequency;
	if(abs(diffFrequency) > sampleRate / 2) {
		[self willChangeValueForKey:@"subFrequency"];
		if(subFrequency > frequency) {
			subFrequency = frequency + (sampleRate / 2);
		} else {
			subFrequency = frequency - (sampleRate / 2);
		}
		[self didChangeValueForKey:@"subFrequency"];
		diffFrequency = frequency - subFrequency;
	}
		
	SetRXOsc(0, 1, (double) diffFrequency);
}

-(int)frequency {
    return (int) [[XTReceiver mainReceiver] frequency];
}

-(void)setAGC:(int) theAGCSetting {
	[self willChangeValueForKey:@"AGC"];
	AGC = theAGCSetting;
	switch(theAGCSetting) {
		case AGC_OFF:
			SetRXAGC(0, 0, agcOFF);
			break;
		case AGC_LONG:
			SetRXAGC(0, 0, agcLONG);
			break;
		case AGC_SLOW:
			SetRXAGC(0, 0, agcSLOW);
			break;
		case AGC_MED:
			SetRXAGC(0, 0, agcMED);
			break;
		case AGC_FAST:
			SetRXAGC(0, 0, agcFAST);
			break;
	}
	[self didChangeValueForKey:@"AGC"];
}

-(void)setSubAGC:(int) theAGCSetting {
	[self willChangeValueForKey:@"subAGC"];
	subAGC = theAGCSetting;
	switch(theAGCSetting) {
		case AGC_OFF:
			SetRXAGC(0, 1, agcOFF);
			break;
		case AGC_LONG:
			SetRXAGC(0, 1, agcLONG);
			break;
		case AGC_SLOW:
			SetRXAGC(0, 1, agcSLOW);
			break;
		case AGC_MED:
			SetRXAGC(0, 1, agcMED);
			break;
		case AGC_FAST:
			SetRXAGC(0, 1, agcFAST);
			break;
	}
	[self didChangeValueForKey:@"subAGC"];
}


-(void)setSubFrequency:(int) theFrequency {
	int diffFrequency;
	
	diffFrequency = frequency - theFrequency;
	
	if(abs(diffFrequency) > sampleRate / 2) {
		NSLog(@"Subreciever Frequency %d out of passband for main frequency %d\n", theFrequency, frequency);
		return;
	}
	
	[self willChangeValueForKey:@"subFrequency"];
	subFrequency = theFrequency;
	SetRXOsc(0, 1, (double) diffFrequency);
	[self didChangeValueForKey:@"subFrequency"];
}

-(void)setSubEnabled:(BOOL) isEnabled {
	[self willChangeValueForKey:@"subEnabled"];
	subEnabled = isEnabled;
	SetSubRXSt(0, 1, subEnabled);
	[self didChangeValueForKey:@"subEnabled"];
	if(isEnabled == NO) {
		self.subMeterReading = -70.0;
	}
}

-(void)setSampleRate:(int) theSampleRate {
	sampleRate = theSampleRate;
	[self initDSP];
}

-(void)setFilterHigh:(double) theFilterHighValue {
	[self willChangeValueForKey:@"filterHigh"];
	if(filterHigh == theFilterHighValue) return;
	
	filterHigh = theFilterHighValue;
	if(filterSymmetry == TRUE) {
		[self willChangeValueForKey:@"filterLow"];
		filterLow = filterHigh;
		[self didChangeValueForKey:@"filterLow"];
	}

	SetRXFilter(0, 0, filterLow, filterHigh);
	SetTXFilter(1, filterLow, filterHigh);
	[self didChangeValueForKey:@"filterHigh"];
}

-(void)setFilterLow:(double) _filterLow {
	[self willChangeValueForKey:@"filterLow"];
	if(filterLow == _filterLow) return;
	
	filterLow = _filterLow;
	if(filterSymmetry == TRUE) {
		[self willChangeValueForKey:@"filterHigh"];
		filterHigh = -filterLow;
		[self didChangeValueForKey:@"filterHigh"];
	}

	SetRXFilter(0, 0, filterLow, filterHigh);
	SetTXFilter(1, filterLow, filterHigh);
	[self didChangeValueForKey:@"filterLow"];
}

-(void)setSubFilterHigh:(double) theFilterHighValue {
	[self willChangeValueForKey:@"subFilterHigh"];
	if(subFilterHigh == theFilterHighValue) return;
	
	subFilterHigh = theFilterHighValue;
	if(filterSymmetry == TRUE) {
		[self willChangeValueForKey:@"subFilterLow"];
		subFilterLow = -subFilterHigh;
		[self didChangeValueForKey:@"subFilterLow"];
	}
	
	SetRXFilter(0, 1, subFilterLow, subFilterHigh);
	[self didChangeValueForKey:@"subFilterHigh"];
}

-(void)setSubFilterLow:(double) theFilterValue {
	[self willChangeValueForKey:@"subFilterLow"];
	if(subFilterLow == theFilterValue) return;
	
	subFilterLow = theFilterValue;
	if(filterSymmetry == TRUE) {
		[self willChangeValueForKey:@"subFilterHigh"];
		subFilterHigh = -subFilterLow;
		[self didChangeValueForKey:@"subFilterHigh"];
	}
	
	SetRXFilter(0, 1, subFilterLow, subFilterHigh);
	[self didChangeValueForKey:@"subFilterLow"];
}

-(void)initDSP {
	SetSampleRate((double)sampleRate);
	
	SetSubRXSt(0, 0, TRUE);
	SetRXOsc(0, 0, 0.0);
	
    /* SetRXOutputGain(0, 0, volume);
	SetMode(0, 0, mode);
	SetRXFilter(0, 0, filterLow, filterHigh);
	SetRXPan(0, 0, pan); */
    [[XTReceiver mainReceiver] setMode:mode];
    [[XTReceiver mainReceiver] setFilterLow:filterLow andHigh:filterHigh];
    [[XTReceiver mainReceiver] setPan:pan];
    [[XTReceiver mainReceiver] setGain:volume];
	
	SetRXOsc(0, 1, (double) subFrequency - frequency);
    
    /*
	SetRXOutputGain(0, 1, subVolume);
	SetMode(0, 1, subMode);
	SetRXFilter(0, 1, filterLow, filterHigh);
	SetRXPan(0, 1, subPan); */
    [[XTReceiver subReceiver] setGain:subVolume];
    [[XTReceiver subReceiver] setMode:subMode];
    [[XTReceiver subReceiver] setFilterLow:subFilterLow andHigh:subFilterHigh];
    [[XTReceiver subReceiver] setPan:subPan];
	
	SetSubRXSt(0, 1, subEnabled);
	
	SetTXOsc(1, 0.0);
    
    /*
	SetMode(1, 0, mode);
	SetTXFilter(1, filterLow, filterHigh); */
}

-(IBAction)changeFilter:(id) sender {
	int filterWidth = [[sender selectedCell] tag];
		
	if(mode == MODE_LSB) {
		self.filterHigh = 150.0;
		self.filterLow = (float) (-(filterWidth - 150));
	} else if(mode == MODE_USB) {
		self.filterLow = -150.0;
		self.filterHigh = (float) (filterWidth - 150);
	} else {
		filterWidth /= 2;
		self.filterHigh = (float) filterWidth;
		self.filterLow = (float) (-filterWidth);
	}
}

-(IBAction)changeSubFilter:(id) sender {
	int filterWidth = [[sender selectedCell] tag];
		
	if(subMode == MODE_LSB) {
		self.subFilterHigh = 150.0;
		self.subFilterLow = (float) (-(filterWidth - 150));
	} else if(subMode == MODE_USB) {
		self.subFilterLow = -150.0;
		self.subFilterHigh = (float) (filterWidth - 150);
	} else {
		filterWidth /= 2;
		self.subFilterHigh = (float) filterWidth;
		self.subFilterLow = (float) (-filterWidth);
	}
}

-(void)recalcFilterPresets {
	NSArray *filterForMode = [filterList objectAtIndex:mode];
	for(NSButton *theButton in [filterMatrix cells]) {
		NSArray *thisFilterSpec = [filterForMode objectAtIndex:[[filterMatrix cells] indexOfObject:theButton]];
		[theButton setTitle:[thisFilterSpec objectAtIndex:0]];
		[theButton setTag:[[thisFilterSpec objectAtIndex:1] intValue]];
	}
}

-(void)recalcSubFilterPresets {
	NSArray *filterForMode = [subFilterList objectAtIndex:subMode];
	for(NSButton *theButton in [subFilterMatrix cells]) {
		NSArray *thisFilterSpec = [filterForMode objectAtIndex:[[subFilterMatrix cells] indexOfObject:theButton]];
		[theButton setTitle:[thisFilterSpec objectAtIndex:0]];
		[theButton setTag:[[thisFilterSpec objectAtIndex:1] intValue]];
	}	
}

-(IBAction)doPreferences:(id) sender {
	if(prefsPane == nil) {
		if(![NSBundle loadNibNamed:@"Preferences" owner:self] ) {
			NSLog(@"Load of Preferences.nib failed\n");
		}
	}
	
	NSTableColumn *column = [[driverTableView tableColumns] objectAtIndex:0];
	XTImageTextCell *cell = [[XTImageTextCell alloc] init];
	[column setDataCell:cell];
		
	if(![[[prefsPane contentView] subviews] containsObject:[interface configWindow]]) {
		NSView *configWindow = [interface configWindow];
		NSRect viewFrame = [hardwarePreferencesView frame];
		NSRect newFrame = [configWindow frame];
		NSRect windowFrame = [prefsPane frame];
		
		NSLog(@"Old View: %f,%f %fx%f\n", viewFrame.origin.x, viewFrame.origin.y, viewFrame.size.width, viewFrame.size.height);
		NSLog(@"New View: %f,%f %fx%f\n", newFrame.origin.x, newFrame.origin.y, newFrame.size.width, newFrame.size.height);
		NSLog(@"Window Frame: %f,%f %fx%f\n", windowFrame.origin.x, windowFrame.origin.y, windowFrame.size.width, windowFrame.size.height);
		
		/* NSLog(@"Origin is %f,%f\n", viewFrame.origin.x, viewFrame.origin.y);
		viewFrame.origin.y -= 10; */
		viewFrame.origin.y = newFrame.origin.y;
		[configWindow setFrameOrigin:viewFrame.origin];
		
		[[hardwarePreferencesView superview] replaceSubview:hardwarePreferencesView with:configWindow];
		hardwarePreferencesView = configWindow;
		NSRect configFrame = [configWindow frame];
		
		
		windowFrame.size.width += configFrame.size.width - viewFrame.size.width;
		windowFrame.size.height += configFrame.size.height - viewFrame.size.height;
		
		[prefsPane setFrame:windowFrame display:YES animate:YES];
	}

	[prefsPane makeKeyAndOrderFront:nil];
}

@end