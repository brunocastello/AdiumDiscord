/*
 * Discord for Adium
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 */

#import "ADDiscordJoinChatViewController.h"
#import "ADDiscordBridge.h"
#import <AdiumLibpurple/CBPurpleAccount.h>
#import <Adium/DCJoinChatWindowController.h>

static NSString *stringOrFallback(const gchar *string, NSString *fallback)
{
	NSString *result = (string ? [NSString stringWithUTF8String:string] : nil);
	return (result ? result : fallback);
}

// DiscordAdiumChannelFunc: collects channels into a dictionary of servers keyed by server ID
static void addChannel(const gchar *guild_id, const gchar *guild_name,
                       const gchar *category_name, gint category_position,
                       const gchar *channel_id, const gchar *channel_name,
                       gint channel_position, gpointer user_data)
{
	NSMutableDictionary *serversByID = user_data;
	NSString *serverID = stringOrFallback(guild_id, @"");
	NSMutableDictionary *server = [serversByID objectForKey:serverID];

	if (!server) {
		server = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		          stringOrFallback(guild_name, serverID), @"name",
		          [NSMutableArray array], @"channels",
		          nil];
		[serversByID setObject:server forKey:serverID];
	}

	[(NSMutableArray *)[server objectForKey:@"channels"] addObject:[NSDictionary dictionaryWithObjectsAndKeys:
	                                              stringOrFallback(channel_id, @""), @"id",
	                                              stringOrFallback(channel_name, @""), @"name",
	                                              stringOrFallback(category_name, @""), @"category",
	                                              [NSNumber numberWithInt:category_position], @"categoryPosition",
	                                              [NSNumber numberWithInt:channel_position], @"position",
	                                              nil]];
}

// Discord's order: channels without a category first, then by category, then by position
static NSComparisonResult compareChannels(NSDictionary *a, NSDictionary *b, void *context)
{
	NSComparisonResult result;

	result = [[a objectForKey:@"categoryPosition"] compare:[b objectForKey:@"categoryPosition"]];
	if (result == NSOrderedSame)
		result = [[a objectForKey:@"category"] localizedCaseInsensitiveCompare:[b objectForKey:@"category"]];
	if (result == NSOrderedSame)
		result = [[a objectForKey:@"position"] compare:[b objectForKey:@"position"]];
	if (result == NSOrderedSame)
		result = [[a objectForKey:@"name"] localizedCaseInsensitiveCompare:[b objectForKey:@"name"]];

	return result;
}

static NSComparisonResult compareServers(NSDictionary *a, NSDictionary *b, void *context)
{
	return [[a objectForKey:@"name"] localizedCaseInsensitiveCompare:[b objectForKey:@"name"]];
}

static NSTextField *newLabel(NSString *title, NSRect frame)
{
	NSTextField *label = [[NSTextField alloc] initWithFrame:frame];

	[label setStringValue:title];
	[label setEditable:NO];
	[label setSelectable:NO];
	[label setBezeled:NO];
	[label setDrawsBackground:NO];
	[label setAlignment:NSRightTextAlignment];

	return label;
}

@interface ADDiscordJoinChatViewController ()
- (void)reloadWithServersByID:(NSDictionary *)serversByID;
- (void)serverChanged:(id)sender;
- (void)channelChanged:(id)sender;
- (void)validate;
- (NSString *)enteredChannelID;
@end

@implementation ADDiscordJoinChatViewController

- (id)init
{
	if ((self = [super init])) {
		NSTextField *label;

		view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 360, 98)];

		label = newLabel(@"Server:", NSMakeRect(0, 72, 86, 17));
		[view addSubview:label];
		[label release];

		popUp_server = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(89, 66, 268, 26) pullsDown:NO];
		[popUp_server setTarget:self];
		[popUp_server setAction:@selector(serverChanged:)];
		[view addSubview:popUp_server];

		label = newLabel(@"Channel:", NSMakeRect(0, 42, 86, 17));
		[view addSubview:label];
		[label release];

		popUp_channel = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(89, 36, 268, 26) pullsDown:NO];
		[popUp_channel setTarget:self];
		[popUp_channel setAction:@selector(channelChanged:)];
		[view addSubview:popUp_channel];

		label = newLabel(@"Or link/ID:", NSMakeRect(0, 9, 86, 17));
		[view addSubview:label];
		[label release];

		textField_channelID = [[NSTextField alloc] initWithFrame:NSMakeRect(92, 6, 262, 22)];
		[[textField_channelID cell] setPlaceholderString:@"Paste a channel link or ID"];
		[textField_channelID setDelegate:self];
		[view addSubview:textField_channelID];
	}

	return self;
}

- (void)dealloc
{
	[popUp_server release];
	[popUp_channel release];
	[textField_channelID release];
	[servers release];

	[super dealloc];
}

- (void)configureForAccount:(AIAccount *)inAccount
{
	[super configureForAccount:inAccount];

	NSMutableDictionary *serversByID = [NSMutableDictionary dictionary];
	PurpleAccount *purpleAccount = [(CBPurpleAccount *)inAccount purpleAccount];
	PurpleConnection *pc = (purpleAccount ? purple_account_get_connection(purpleAccount) : NULL);

	if (pc && PURPLE_CONNECTION_IS_CONNECTED(pc))
		discord_adium_foreach_channel(pc, addChannel, serversByID);

	[self reloadWithServersByID:serversByID];
}

// serversByID: server ID -> { name, channels (NSMutableArray of channel dictionaries) }
- (void)reloadWithServersByID:(NSDictionary *)serversByID
{
	NSMutableArray *sortedServers = [NSMutableArray arrayWithArray:[serversByID allValues]];
	[sortedServers sortUsingFunction:compareServers context:NULL];
	for (NSMutableDictionary *server in sortedServers)
		[[server objectForKey:@"channels"] sortUsingFunction:compareChannels context:NULL];

	[servers release];
	servers = [sortedServers retain];

	[popUp_server removeAllItems];
	for (NSDictionary *server in servers) {
		[popUp_server addItemWithTitle:@""];
		// Set the title separately so names that match an existing item are not merged
		[[popUp_server lastItem] setTitle:[server objectForKey:@"name"]];
		[[popUp_server lastItem] setRepresentedObject:server];
	}
	[popUp_server setEnabled:([servers count] > 0)];

	[self serverChanged:nil];
}

- (void)serverChanged:(id)sender
{
	NSDictionary *server = [[popUp_server selectedItem] representedObject];
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSString *lastCategory = nil;
	NSMenuItem *firstChannel = nil;

	[menu setAutoenablesItems:NO];

	for (NSDictionary *channel in [server objectForKey:@"channels"]) {
		NSString *category = [channel objectForKey:@"category"];
		NSMenuItem *item;

		if ([category length] && ![category isEqualToString:lastCategory]) {
			item = [[[NSMenuItem alloc] initWithTitle:[category uppercaseString] action:NULL keyEquivalent:@""] autorelease];
			[item setEnabled:NO];
			[menu addItem:item];
		}
		lastCategory = category;

		item = [[[NSMenuItem alloc] initWithTitle:[@"#" stringByAppendingString:[channel objectForKey:@"name"]]
		                                   action:NULL
		                            keyEquivalent:@""] autorelease];
		[item setRepresentedObject:channel];
		if ([category length])
			[item setIndentationLevel:1];
		[menu addItem:item];

		if (!firstChannel)
			firstChannel = item;
	}

	[popUp_channel setMenu:menu];
	if (firstChannel)
		[popUp_channel selectItem:firstChannel];
	[popUp_channel setEnabled:(firstChannel != nil)];

	[self validate];
}

- (void)channelChanged:(id)sender
{
	[self validate];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	[self validate];
}

// A channel ID, or the ID at the end of a channel link (https://discord.com/channels/<server>/<channel>)
- (NSString *)enteredChannelID
{
	NSString *entered = [[textField_channelID stringValue] stringByTrimmingCharactersInSet:
	                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *lastPart;

	while ([entered hasSuffix:@"/"])
		entered = [entered substringToIndex:[entered length] - 1];

	lastPart = [[entered componentsSeparatedByString:@"/"] lastObject];
	if ([lastPart length] &&
	    [[lastPart stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] length] == 0)
		return lastPart;

	return nil;
}

- (void)validate
{
	BOOL canJoin = ([self enteredChannelID] != nil || [[popUp_channel selectedItem] representedObject] != nil);

	if ([delegate respondsToSelector:@selector(setJoinChatEnabled:)])
		[delegate setJoinChatEnabled:canJoin];
}

- (void)joinChatWithAccount:(AIAccount *)inAccount
{
	NSString *channelID = [self enteredChannelID];
	NSString *channelName = channelID;

	if (!channelID) {
		NSDictionary *channel = [[popUp_channel selectedItem] representedObject];
		channelID = [channel objectForKey:@"id"];
		channelName = [channel objectForKey:@"name"];
	}

	if (![channelID length])
		return;

	/* The chat is named after the channel ID: purple-discord names the conversation that, and
	 * the chat's title becomes "#channel (Server)" once it opens. */
	[self doJoinChatWithName:channelID
	               onAccount:inAccount
	        chatCreationInfo:[NSDictionary dictionaryWithObjectsAndKeys:
	                          channelID, @"id",
	                          channelName, @"name",
	                          nil]
	        invitingContacts:nil
	   withInvitationMessage:nil];
}

@end
