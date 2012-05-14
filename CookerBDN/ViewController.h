//  
//  ViewController.h
//  CookerBDN
//  
//  Created by Judith Tsai on 5/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//  

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>


typedef struct {
	
} egg;

typedef enum {
	sessionServer,
	sessionClient
} networkCharacter;

typedef enum {
	modeStart,
	modePeerPicker,
	modeDecideServer,
	modeGame,
} gameModes;

typedef enum {
	DATA_ACK,					// no packet
	DATA_DECIDE_SERVER,				// decide who is going to be the server
	DATA_GAME_EGG,
	DATA_GAME_POINT,
	DATA_GAME_FLY,
} dataType;

// GameKit Session ID for our app
#define mySessionID @"CookerBDN"

#define myMaxPacketSize 1024


#pragma mark -

@interface ViewController : UIViewController<GKPeerPickerControllerDelegate, GKSessionDelegate, UIAlertViewDelegate,UIAccelerometerDelegate>{
	
	IBOutlet UILabel		*testLabel;
	IBOutlet UITextField	*_nameTextField;
	IBOutlet UILabel		*_letsGO;
	
	// game status
	NSInteger	_gameMode;
	NSInteger	_severOrClient;
	
	// networking
	GKSession		*_gameSession;
	int				_gameUniqueID;
//	int				_gamePacketNumber;
	NSString		*_gamePeerId;
//  NSDate			*lastHeartbeatDate;
	
	UIAlertView		*_connectionAlert;
}

# pragma mark - Variables

# pragma mark Game Status 
@property(nonatomic) NSInteger		_gameMode;
@property(nonatomic) NSInteger		_severOrClient;

# pragma mark Networking
@property(nonatomic, retain) GKSession	 *_gameSession;
@property(nonatomic, copy)	 NSString	 *_gamePeerId;
//  @property(nonatomic, retain) NSDate		 *lastHeartbeatDate;
@property(nonatomic, retain) UIAlertView *_connectionAlert;


# pragma mark - Methods

- (int)generateCFUUID;

- (void)invalidateSession:(GKSession *)session;

- (IBAction)tempButton:(id)sender;

- (void)startPeerPicker;

- (void)gameLoop;
- (void)sendData:(GKSession *)session withDataType:(int)dataType withData:(void *)data ofLength:(int)length reliable:(BOOL)howtosend;


@end
