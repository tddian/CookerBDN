//  
//  ViewController.h
//  CookerBDN
//  
//  Created by Judith Tsai on 5/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//  

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>
#import <AVFoundation/AVFoundation.h>

//@class SpeakHereController;


typedef struct {
	
} Egg;

typedef enum {
	nServer,
	nClient
} NetworkCharacter;

typedef enum {
	modeStart,
	modePeerPicker,
	modeDecideServer,
	modeGame,
} GameModes;

typedef enum {
	DATA_DECIDE_SERVER,				// decide who is going to be the server
	DATA_GAME_EGG,
	DATA_GAME_GRADE,
	DATA_GAME_FLY,
} DataType;

// GameKit Session ID for our app
#define mySessionID @"CookerBDN"

#define myMaxPacketSize 1024*1024


#pragma mark -

@interface ViewController : UIViewController<GKPeerPickerControllerDelegate, GKSessionDelegate, UIAlertViewDelegate,UIAccelerometerDelegate,AVAudioRecorderDelegate>{
	
	IBOutlet UILabel		*testLabel;
	IBOutlet UITextField	*_nameTextField;
	IBOutlet UIButton		*btn_play;
	IBOutlet UIButton		*btn_record;
	
//	IBOutlet SpeakHereController	*speak;
	
	BOOL	isBurn;
	BOOL	isFly;
	BOOL	isNewEgg;
	
	BOOL	recordedAudioNeedSave;
	
	float	accumulatePower;
	
	// game status
	NSInteger	_gameMode;
	NSInteger	_severOrClient;
	
	// networking
	GKSession		*_gameSession;
	int				_gameUUID;
//	int				_gamePacketNumber;
	NSString		*_gamePeerId;
//  NSDate			*lastHeartbeatDate;
	
	UIAlertView		*_connectionAlert;
	
	NSString		*filePath;
	NSDictionary	*settings;

}

# pragma mark - Variables

// recorded file path
//@property(nonatomic, retain) NSArray			*paths;
//@property(nonatomic, retain) NSString		*documentsDirectory;
@property(nonatomic, retain) NSString		*filePath;
@property(nonatomic, retain) NSDictionary	*settings;


# pragma mark Game Status 
@property(nonatomic) NSInteger		_gameMode;
@property(nonatomic) NSInteger		_severOrClient;

@property(nonatomic, retain) NSTimer* avRecorderTimer;

# pragma mark Networking
@property(nonatomic, retain) GKSession	 *_gameSession;
@property(nonatomic, copy)	 NSString	 *_gamePeerId;
//  @property(nonatomic, retain) NSDate		 *lastHeartbeatDate;
@property(nonatomic, retain) UIAlertView *_connectionAlert;

@property (nonatomic, retain)	NSData *recordedData;
@property (nonatomic, retain)	AVAudioPlayer *audioPlayer;
@property (nonatomic, retain)	AVAudioRecorder *audioRecorder;

//@property(nonatomic, retain) SpeakHereController *speak;


# pragma mark - Methods

- (int)generateCFUUID;

- (void)invalidateSession:(GKSession *)session;

- (IBAction)tempButton:(id)sender;

- (IBAction)burn:(id)sender;

- (IBAction)fly:(id)sender;

- (IBAction)newegg:(id)sender;


- (void)startPeerPicker;

- (void)gameLoop;
- (void)sendData:(GKSession *)session withDataType:(int)dataType withData:(void *)data ofLength:(int)length reliable:(BOOL)howtosend;

- (void)audioRecorderStart;

- (void)audioRecorderSave;

- (void)play:(NSData*)audioData;

- (void)audioRecorderTimerDetecter:(NSTimer *)timer;

- (void)initialParameter;

@end
