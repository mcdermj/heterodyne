//
//  TransceiverController.h
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

#import "XTHeterodyneHardwareDriver.h"
#import "dttsp.h"

#define MODE_LSB 0
#define MODE_USB 1
#define MODE_DSB 2
#define MODE_CWL 3
#define MODE_CWU 4
#define MODE_FMN 5
#define MODE_AM 6
#define MODE_DIGU 7
#define MODE_SPEC 8
#define MODE_DIGL 9
#define MODE_SAM 10
#define MODE_DRM 11

#define AGC_OFF 0
#define AGC_LONG 1
#define AGC_SLOW 2
#define AGC_MED 3
#define AGC_FAST 4

@class XTDTTSP;
@class XTWorkerThread;

@interface TransceiverController : NSObject {
	
	IBOutlet NSMatrix *filterMatrix;
	IBOutlet NSMatrix *subFilterMatrix;
	IBOutlet NSTableView *driverTableView;
	
	IBOutlet NSView *hardwarePreferencesView;
	
	int frequency;
	int subFrequency;
	int mode;
	int subMode;
	int sampleRate;
	int AGC;
	int subAGC;
	
	double filterHigh, filterLow;
	double subFilterHigh, subFilterLow;
	
	double volume;
	double subVolume;
	
	float systemAudioGain;
	
	float meterReading;
	float subMeterReading;
	float filterCalibrationOffset;
	float preampOffset;
	
	float pan;
	float subPan;
	
	BOOL filterSymmetry;
	BOOL subEnabled;
	
	BOOL noiseReduction;
	BOOL autoNotchFilter;
	BOOL noiseBlanker;
	BOOL binaural;
	
	BOOL subNoiseReduction;
	BOOL subAutoNotchFilter;
	BOOL subNoiseBlanker;
	BOOL subBinaural;
	
	BOOL preamp;
	
	NSArray *filterList;
	NSArray *subFilterList;
	NSArray *drivers;
	
	int currentDriver;
	
	NSMutableDictionary *bandPlan;
	
	XTWorkerThread *updateThread;
	XTDTTSP *sdr;
	id<XTHeterodyneHardwareDriver> interface;
	
	IBOutlet NSWindow *prefsPane;
	
	NSTimer *meterTimer;
}

@property int frequency;
@property int mode;
@property int subMode;
@property id<XTHeterodyneHardwareDriver> interface;
@property int sampleRate;
@property double filterHigh;
@property double filterLow;
@property double subFilterHigh;
@property double subFilterLow;
@property double volume;
@property float systemAudioGain;
@property float meterReading;
@property float subMeterReading;
@property BOOL filterSymmetry;
@property float pan;
@property float subPan;
@property int subFrequency;
@property double subVolume;
@property BOOL subEnabled;
@property BOOL noiseReduction;
@property BOOL autoNotchFilter;
@property BOOL noiseBlanker;
@property BOOL binaural;
@property BOOL subNoiseReduction;
@property BOOL subAutoNotchFilter;
@property BOOL subNoiseBlanker;
@property BOOL subBinaural;
@property int AGC;
@property int subAGC;
@property (readonly) XTWorkerThread *updateThread;
@property BOOL preamp;
@property (readonly) NSString *band;
@property (readonly) NSDictionary *bandPlan;
@property (readonly) NSArray *drivers;

-(void)updateMeter:(NSTimer *) _timer;
-(void)saveParams;
-(void)refreshParams;
-(void)initDSP;
-(void)start;

-(void)recalcFilterPresets;
-(void)recalcSubFilterPresets;

-(IBAction)changeFilter:(id) sender;
-(IBAction)changeSubFilter:(id) sender;
-(IBAction)bandstackPressed:(id) sender;

-(void)restoreFromDictionary:(NSDictionary *)frequencyDictionary;
-(NSDictionary *)saveToDictionary;

-(IBAction)doPreferences:(id) sender;

@end
