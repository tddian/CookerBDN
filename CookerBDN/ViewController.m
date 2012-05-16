//  
//  ViewController.m
//  CookerBDN
//  
//  Created by Judith Tsai on 5/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//  

#import "ViewController.h"
//#import "SpeakHereController.mm"


# pragma mark -
@implementation ViewController

# pragma mark - Variables
@synthesize _gameMode, _severOrClient, _gameSession, _gamePeerId, _connectionAlert, audioRecorder, audioPlayer, recordedData, avRecorderTimer, settings, filePath;


# pragma mark - Methods -

# pragma mark View Controller
- (void)viewDidLoad
{
	[super viewDidLoad];
	
	// initialize
	isBurn		= NO;
	isFly		= NO;
	isNewEgg	= NO;
	
	recordedAudioNeedSave = NO;
	accumulatePower = 0;
	
	[self initialParameter];
	self.avRecorderTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(audioRecorderTimerDetecter:) userInfo:nil repeats:YES];
	
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
	NSLog(@"CFUUID:%d",_gameUUID);
	
	
//	speak = [[SpeakHereController alloc] init];
	
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

# pragma mark - TEMP BUTTON TESTER

- (IBAction)tempButton:(id)sender {
	[self startPeerPicker];
}



# pragma mark - Peer Picker


- (void)startPeerPicker{
	
	// (Dian:) trim the spaces at the head and tail.
	NSString *text = [_nameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	NSLog(@"%@", text);
	
	if ([text isEqualToString:@""]) {
		_nameTextField.text = @"SPACES?";
	} else {
		GKPeerPickerController	*picker;
		
		self._gameMode = modePeerPicker;			// we're going to do Multiplayer!
		
		picker = [[GKPeerPickerController alloc] init]; // note: picker is released in various picker delegate methods when picker use is done.
//		[picker setConnectionTypesMask:GKPeerPickerConnectionTypeOnline];
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


 - (void)peerPickerController:(GKPeerPickerController *)picker didSelectConnectionType:(GKPeerPickerConnectionType)type{
 
 }
 

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
	
	NSLog(@"receive packet length %d", [packet length]);
	
	static int lastPacketNumber = -1;
	
	unsigned char *ptrPacket = (unsigned char *)[packet bytes];
	int *ptrHeader = (int *)&ptrPacket[0];
	
	// header: [packetNumber][dataType]
	int packetNumber	= ptrHeader[0];
	DataType dataType	= ptrHeader[1];
	
	char *pointer = (char*)&ptrHeader[2];
	
	NSData *data		= [NSData dataWithBytes:pointer length:[packet length]-8];
	NSLog(@"%p, %d", pointer, [packet length]-8);
	
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
		{
			NSLog(@"RECEIVE AN EGG");
		
//			[data retain];
//			[self play:data];
			audioPlayer = [[AVAudioPlayer alloc] initWithData:data error:nil];
			[audioPlayer play];

		}
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
	
	NSLog(@"send: length %d", length);
	
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

- (void)audioRecorderSave{
	
	NSLog(@"stop recording in audioRecorderSave");
	
	recordedAudioNeedSave = YES;
	[self.audioRecorder stop];

}


- (IBAction)burn:(id)sender {
	isBurn = !isBurn;
	NSLog(@"isBurn? %d, isFly? %d, isNewEgg? %d, isrecording? %d", isBurn, isFly, isNewEgg, self.audioRecorder.recording);

//	recordedAudioNeedSave = YES;
	
	if(isBurn){
		accumulatePower = 0;
		[self audioRecorderStart:YES];
	}
	else
		[self audioRecorderSave];
}

- (IBAction)fly:(id)sender {
	isFly = !isFly;
	NSLog(@"isBurn? %d, isFly? %d, isNewEgg? %d, isrecording? %d", isBurn, isFly, isNewEgg, self.audioRecorder.recording);

	if (isFly)
		[self audioRecorderStart:NO];
	else if (!isBurn)
		[self.audioRecorder stop];
}

- (IBAction)newegg:(id)sender {
	isNewEgg = !isNewEgg;
	NSLog(@"isBurn? %d, isFly? %d, isNewEgg? %d, isrecording? %d", isBurn, isFly, isNewEgg, self.audioRecorder.recording);

	if(isNewEgg)
		[self audioRecorderStart:NO];
	else if (!isBurn)
		[self.audioRecorder stop];
}


- (void)audioRecorderStart:(BOOL)forceRestart{
	
	BOOL ing = audioRecorder.recording;
	if(!ing)
	{
		while (![self.audioRecorder prepareToRecord]){
		}
		while (![self.audioRecorder record]){
			NSLog(@"NO!");
		}
		NSLog(@"Start recording");
	} else if( forceRestart && ing ){
		
		[self.audioRecorder stop];
	}

}
- (void)audioRecorderTimerDetecter:(NSTimer *)timer {
	
	static double lpResult = 0;
	static const double ALPHA = 0.05;
	
	if(self.audioRecorder && self.audioRecorder.recording)
	{
		[self.audioRecorder updateMeters];
		
		float powerDB = [self.audioRecorder peakPowerForChannel:0];
		double power = pow(10, (0.05 * powerDB));

//		NSLog(@"%f", power);
		
		if (isBurn){
			accumulatePower += 10 * power;
			NSLog(@"POWER!!!!! %f %%", accumulatePower/100);
		}
		if (isFly) {
			lpResult = ALPHA * power + (1.0 - ALPHA) * lpResult;	
			if (lpResult > 0.8) {
				isFly = NO;
				lpResult = 0;
				NSLog(@"blowing the fly!!!");
			}

		}
		if (isNewEgg) {
			if (powerDB == 0.0)
			{
				isNewEgg = NO;
				NSLog(@"break the shell!");
			}
		}
	}
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag{
	
//	needSave = YES;
	NSLog(@"stop finish");
	
	if (recordedAudioNeedSave) {
//		NSLog(@"save recorded audio in file");
		
		NSString *file = [self.audioRecorder.url path];
		
		self.recordedData = [NSData dataWithContentsOfFile:file options: 0 error:nil];
		
//		NSLog(@"isBurn? %d, isFly? %d, isNewEgg? %d, isrecording? %d", isBurn, isFly, isNewEgg, self.audioRecorder.recording);
		
		//	[self.audioRecorder deleteRecording];
		
		//	// RESTART the recorder if isFly || isNewEgg
		//	if (isFly||isNewEgg) {
		//		[self audioRecorderStart:NO];
		//	}
		
		NSLog(@"recorded length: %d", [recordedData length]);
		
		NSUInteger len = [recordedData length];
		Byte *byteData = (Byte*)malloc(len);
		memcpy(byteData, [recordedData bytes], len);
		
		recordedAudioNeedSave = NO;
		//	[self sendData:self._gameSession withDataType:DATA_GAME_EGG withData:byteData ofLength:[recordedData length] reliable:NO];
	}
		
	if (isFly||isNewEgg) {
		[self audioRecorderStart:NO];
	}
}

- (void)play:(NSData *)audioData{
//	NSString *file = [audioRecorder.url path];
	
//	NSLog(@"Play! : %@", file);
	
	
//	audioData = [NSData dataWithContentsOfFile:file options: 0 error:nil];
	
	audioPlayer = [[AVAudioPlayer alloc] initWithData:audioData error:nil];
	
	
	//	audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioRecorder.url error:nil];
	
	//	[audioPlayer retain];
	[audioPlayer play];
}

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
//	NSLog(@"sizeof(&_gameUUID) = %lu",sizeof(&_gameUUID));
//	NSLog(@"sizeof(_gameUUID)) = %lu",sizeof(_gameUUID));
	NSLog(@"%@", uuidStr);
	NSLog(@"CFUUID:%d",rtn);
	
	CFRelease(uuidStr);
	CFRelease(uuid);
	
	return rtn;
}

- (void)initialParameter{
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	self.filePath = [documentsDirectory stringByAppendingPathComponent:@"audioFile.caf"];  // Where ext is the audio format extension you have recorded your sound
	
	
	self.settings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat: 44100.0], AVSampleRateKey, [NSNumber numberWithInt: kAudioFormatAppleLossless], AVFormatIDKey, [NSNumber numberWithInt: 1],                         AVNumberOfChannelsKey, [NSNumber numberWithInt: AVAudioQualityMax], AVEncoderAudioQualityKey, nil];
	//  	NSError *error;
	NSLog(@"recorde! : %@", filePath);
	
	self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:filePath] settings:settings error:nil];

	self.audioRecorder.meteringEnabled = YES;
	
	self.audioRecorder.delegate = self;

}

@end
