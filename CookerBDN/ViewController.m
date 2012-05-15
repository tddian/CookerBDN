//  
//  ViewController.m
//  CookerBDN
//  
//  Created by Judith Tsai on 5/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//  

#import "ViewController.h"

# pragma mark -
@implementation ViewController

# pragma mark - Variables
@synthesize _gameMode, _severOrClient, _gameSession, _gamePeerId, _connectionAlert;


# pragma mark - Methods -

# pragma mark View Controller
- (void)viewDidLoad
{
	[super viewDidLoad];
	
	// game status
	_gameMode= modeStart;
	_severOrClient= nServer;
	
	// 
	UIAccelerometer *myAccel = [UIAccelerometer sharedAccelerometer];
    myAccel.updateInterval = .1;
    myAccel.delegate = self;
	
	// networking
	_gameSession= nil;
	_gameUUID = [self generateCFUUID];
	//	_gamePacketNumber = 0;
	_gamePeerId = nil;
	
	// debugger
	testLabel.text = [NSString stringWithFormat:@"CFUUID:%d",_gameUUID];
	NSLog([NSString stringWithFormat:@"CFUUID:%d",_gameUUID]);
	
	
	// gameLoop
	[NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(gameLoop) userInfo:nil repeats:YES];
}

- (void)viewDidUnload
{
	[super viewDidUnload];
	// Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)dealloc{
	
	[self invalidateSession:self._gameSession];
	_gameSession= nil;
	_gamePeerId = nil;
	
	if(self._connectionAlert.visible) {
		[self._connectionAlert dismissWithClickedButtonIndex:-1 animated:NO];
	}
	self._connectionAlert = nil;
	
	[super dealloc];
}

# pragma mark - Peer Picker

- (IBAction)tempButton:(id)sender {
	[self startPeerPicker];
}

- (void)startPeerPicker{
	
	// (Dian:) trim the spaces at the head and tail.
	NSString *text = [_nameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	NSLog(text);
	
	if ([text isEqualToString:@""]) {
		_nameTextField.text = @"SPACES?";
	} else {
		GKPeerPickerController	*picker;
		
		self._gameMode = modePeerPicker;			// we're going to do Multiplayer!
		
		picker = [[GKPeerPickerController alloc] init]; // note: picker is released in various picker delegate methods when picker use is done.
		picker.delegate = self;
		[picker show]; // show the Peer Picker
	}
}

# pragma mark GKPeerPickerControllerDelegate

- (void)peerPickerController:(GKPeerPickerController *)picker didConnectPeer:(NSString *)peerID toSession:(GKSession *)session{
	
	// Remember the current peer.
	self._gamePeerId = peerID;// copy
	NSLog(@"peerID: %p", peerID);
	
	// Make sure we have a reference to the game session and it is set up
	self._gameSession = session; // retain
	self._gameSession.delegate = self; 
	[self._gameSession setDataReceiveHandler:self withContext:NULL];
	
	// Done with the Peer Picker so dismiss it.
	[picker dismiss];
	picker.delegate = nil;
	[picker autorelease];
	
	// Start game by entering the decide state to determine who is server/client.
	self._gameMode = modeDecideServer;
	
}

/*
 - (void)peerPickerController:(GKPeerPickerController *)picker didSelectConnectionType:(GKPeerPickerConnectionType)type{
 
 }
 */

- (GKSession *)peerPickerController:(GKPeerPickerController *)picker sessionForConnectionType:(GKPeerPickerConnectionType)type{
	
	GKSession *session = [[GKSession alloc] initWithSessionID:mySessionID displayName:_nameTextField.text sessionMode:GKSessionModePeer]; 
	
	[session autorelease];
	// NOTE(Dian): autorelease the reference so that we won't got memory leak.
	
	return session;
}

// NOTE: Peer Picker automatically dismisses on user cancel. No need to programmatically dismiss.
- (void)peerPickerControllerDidCancel:(GKPeerPickerController *)picker{
	
	// autorelease the picker. 
	picker.delegate = nil;
	[picker autorelease]; 
	
	// invalidate and release game session if one is around.
	if(self._gameSession != nil)	{
		[self invalidateSession:self._gameSession];
		self._gameSession = nil;
	}
	
	// back to start mode
	self._gameMode = modeStart;
	
}

# pragma mark - Session
- (void)invalidateSession:(GKSession *)session {
	if(session != nil) {
		[session disconnectFromAllPeers]; 
		session.available = NO; 
		[session setDataReceiveHandler: nil withContext: NULL]; 
		session.delegate = nil; 
	}
}

# pragma mark GKSessionDelegate
/*- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error{
 
 }
 - (void)session:(GKSession *)session didFailWithError:(NSError *)error{
 
 }
 - (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID{
 
 }*/
- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state{
	if(self._gameMode == modeStart) {
		return;				// only do stuff if we're in multiplayer, otherwise it is probably for Picker
	}
	
	if(state == GKPeerStateDisconnected) {
		// We've been disconnected from the other peer.
		
		// Update user alert or throw alert if it isn't already up
		NSString *message = [NSString stringWithFormat:@"Could not reconnect with %@.", [session displayNameForPeer:peerID]];
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Lost Connection" message:message delegate:self cancelButtonTitle:@"End Game" otherButtonTitles:nil];
		self._connectionAlert = alert;
		[alert show];
		[alert release];
		
		// go back to start mode
		self._gameMode = modeStart; 
	} 
}
#pragma mark Data Send/Receive
/*
 * Getting a data packet. This is the data receive handler method expected by the GKSession. 
 * We set ourselves as the receive data handler in the -peerPickerController:didConnectPeer:toSession: method.
 */
- (void)receiveData:(NSData *)packet fromPeer:(NSString *)peer inSession:(GKSession *)session context:(void *)context { 
	
	static int lastPacketNumber = -1;
	
	unsigned char *ptrPacket = (unsigned char *)[packet bytes];
	int *ptrHeader = (int *)&ptrPacket[0];
	
	// header: [packetNumber][dataType]
	int packetNumber	= ptrHeader[0];
	DataType dataType	= ptrHeader[1];
	
	switch (dataType) {
		case DATA_DECIDE_SERVER:
		{
			NSLog(@"RECEIVE UUID");

			int peerUUID = ptrHeader[2];
			if (peerUUID > _gameUUID) {
				self._severOrClient = nClient;
				NSLog(@"\tI am client");
			} else {
				self._severOrClient = nServer;
				NSLog(@"\tI am server");
			}
			
			// after 1 second fire method to hide the label
			//			[NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(hideGameLabel:) userInfo:nil repeats:NO];
		}	
			break;
		case DATA_GAME_EGG:
			break;
		case DATA_GAME_GRADE:
			break;
		case DATA_GAME_FLY:
			break;
		default:
			break;
	}
}

- (void)sendData:(GKSession *)session withDataType:(int)dataType withData:(void *)data ofLength:(int)length reliable:(BOOL)howtosend {
	
	// static: the packet we'll send is resued
	static int packetNumber = 0;
	static unsigned char buffer[myMaxPacketSize];
	static const unsigned int packetHeaderSize = 2 * sizeof(int); // we have two "ints" for our header
	static int *packetHeader = (int *)&buffer[0];
	//	int *pIntData = (int *)networkPacket;
	
	assert(length < (myMaxPacketSize - packetHeaderSize));
	// our networkPacket buffer size minus the size of the header info
	
	// prepare the header
	packetHeader[0] = packetNumber++;
	packetHeader[1] = dataType;
	
	// copy data in after the header
	memcpy( &buffer[packetHeaderSize], data, length ); 
	
	NSData *packet = [NSData dataWithBytes: buffer length: (length+packetHeaderSize)];
	if(howtosend == YES) { 
		[session sendData:packet toPeers:[NSArray arrayWithObject:_gamePeerId] withDataMode:GKSendDataReliable error:nil];
	} else {
		[session sendData:packet toPeers:[NSArray arrayWithObject:_gamePeerId] withDataMode:GKSendDataUnreliable error:nil];
	}
	
}

# pragma mark - ALL About the GAME Algorithm :3
//  
// Game loop runs at regular interval to update game based on current game mode
//  
- (void)gameLoop {
	switch (self._gameMode) {
		case modeStart:
		case modePeerPicker:
			break;
		case modeDecideServer:
		{
			NSLog(@"SEND UUID");
			[self sendData:self._gameSession withDataType:DATA_DECIDE_SERVER withData:&_gameUUID ofLength:sizeof(&_gameUUID) reliable:YES];
			self._gameMode = modeGame; // make us in modeDecideServer state for one loop
		}
			break;
		case modeGame:
			// in the game
			break;
		default:
			break;
	}
}

# pragma mark - Utility Methods
- (int)generateCFUUID{
	
	//  CFUUID objects are used by plug-ins to uniquely identify types, interfaces, and factories. When creating a new type, host developers must generate UUIDs to identify the type as well as its interfaces and factories.
	//  UUIDs (Universally Unique Identifiers), also known as GUIDs (Globally Unique Identifiers) or IIDs (Interface Identifiers), are 128-bit values guaranteed to be unique. A UUID is made unique over both space and time by combining a value unique to the computer on which it was generated—usually the Ethernet hardware address—and a value representing the number of 100-nanosecond intervals since October 15, 1582 at 00:00:00.
	
	
	
	CFUUIDRef uuid;
	CFStringRef uuidStr;
	int rtn;
	
	uuid = CFUUIDCreate(NULL);
	assert(uuid != NULL);
	
	uuidStr = CFUUIDCreateString(NULL, uuid);
	assert(uuidStr != NULL);
	
	rtn = CFStringGetIntValue(uuidStr);
	
	// debugger
	NSLog(@"sizeof(&_gameUUID) = %lu",sizeof(&_gameUUID));
	NSLog(@"sizeof(_gameUUID)) = %lu",sizeof(_gameUUID));
	NSLog([NSString stringWithFormat:@"%@", uuidStr]);
	NSLog([NSString stringWithFormat:@"CFUUID:%d",rtn]);
	
	CFRelease(uuidStr);
	CFRelease(uuid);
	
	return rtn;
}

@end
