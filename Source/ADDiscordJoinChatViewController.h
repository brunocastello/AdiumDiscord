/*
 * Discord for Adium
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 */

#import <Adium/DCJoinChatViewController.h>

// The Discord panel of File > Join Group Chat: pick a server and one of its channels (or one of
// the group DMs), or paste a channel ID. Built in code, since CI cannot compile nibs.
@interface ADDiscordJoinChatViewController : DCJoinChatViewController <NSTextFieldDelegate> {
	NSPopUpButton	*popUp_server;
	NSPopUpButton	*popUp_channel;
	NSTextField		*label_channel;
	NSTextField		*textField_channelID;

	NSArray			*servers;	// of NSDictionary: name, channels (sorted)
}
@end
