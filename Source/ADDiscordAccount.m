/*
 * Discord for Adium
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 */

/*
 * Login
 * -----
 * purple-discord logs in with the "token" account setting if there is one, otherwise with
 * email + password (asking for a 2FA code when needed). Pidgin persists that setting in
 * accounts.xml; Adium recreates its PurpleAccounts on every launch, so we keep the token ourselves:
 *
 *  - If the password Adium hands us looks like a Discord token, it is used as the token directly.
 *    This is the way around Discord's CAPTCHA, which the plugin cannot show.
 *  - After a successful email/password login, the token Discord issued is saved in the Keychain
 *    and used on later connects, so the password (and 2FA) are not needed again.
 *  - If Discord rejects a token, the saved one is forgotten and the failure is reported as a bad
 *    password, which makes Adium ask for it again instead of reconnecting forever.
 */

#import "ADDiscordAccount.h"
#import <Adium/AIStatus.h>
#import <Adium/AIStatusControllerProtocol.h>
#import <Adium/ESDebugAILog.h>
#import <AIUtilities/AIKeychain.h>
#import <Adium/AIChat.h>
#import "ADDiscordBridge.h"

#define DISCORD_KEYCHAIN_SERVICE	@"Adium Discord token"
#define DISCORD_PRPL_ID				"prpl-eionrobb-discord"

// Tokens are three base64url segments joined by dots; passwords essentially never look like that.
static BOOL looksLikeToken(NSString *string)
{
	if ([string length] < 50 || [[string componentsSeparatedByString:@"."] count] != 3)
		return NO;

	NSCharacterSet *tokenChars = [NSCharacterSet characterSetWithCharactersInString:
		@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."];
	return [[string stringByTrimmingCharactersInSet:tokenChars] length] == 0;
}

// Removes the account's chats from libpurple's buddy list, and the groups purple-discord made
// for them (it tags those with an "id") once they are empty.
static void removeBlistChatsForAccount(PurpleAccount *purpleAccount)
{
	PurpleBlistNode *group, *nextGroup, *node, *nextNode;

	for (group = purple_blist_get_root(); group; group = nextGroup) {
		nextGroup = purple_blist_node_get_sibling_next(group);
		if (!PURPLE_BLIST_NODE_IS_GROUP(group))
			continue;

		for (node = purple_blist_node_get_first_child(group); node; node = nextNode) {
			nextNode = purple_blist_node_get_sibling_next(node);
			if (PURPLE_BLIST_NODE_IS_CHAT(node) && purple_chat_get_account(PURPLE_CHAT(node)) == purpleAccount)
				purple_blist_remove_chat(PURPLE_CHAT(node));
		}

		if (!purple_blist_node_get_first_child(group) && purple_blist_node_get_string(group, "id"))
			purple_blist_remove_group(PURPLE_GROUP(group));
	}
}

@implementation ADDiscordAccount

- (const char *)protocolPlugin
{
	return DISCORD_PRPL_ID;
}

// Adium registers third-party protocols only after libpurple has loaded accounts.xml, so the
// PurpleAccount restored for us at launch has no status types and no presence, and setting any
// status (going online included) fails with "Invalid status ID". Finish what
// purple_account_new() does when the protocol is already known.
- (void)setPurpleAccount:(PurpleAccount *)inAccount
{
	[super setPurpleAccount:inAccount];

	if (inAccount && !purple_account_get_presence(inAccount)) {
		PurplePlugin *prpl = purple_find_prpl(purple_account_get_protocol_id(inAccount));
		PurplePluginProtocolInfo *prpl_info = (prpl ? PURPLE_PLUGIN_PROTOCOL_INFO(prpl) : NULL);

		if (prpl_info && prpl_info->status_types) {
			AILog(@"Discord: giving %@'s restored PurpleAccount its statuses", self.UID);
			purple_account_set_status_types(inAccount, prpl_info->status_types(inAccount));
			inAccount->presence = purple_presence_new_for_account(inAccount);

			PurpleStatusType *available = purple_account_get_status_type_with_primitive(inAccount, PURPLE_STATUS_AVAILABLE);
			purple_presence_set_status_active(inAccount->presence,
			                                  (available ? purple_status_type_get_id(available) : "offline"), TRUE);
		}
	}
}

// purple-discord has its servers built in; Adium only uses this for its reachability check,
// and prompts "No Server Specified" when it is empty.
- (NSString *)host
{
	return @"discord.com";
}

#pragma mark Token storage

- (NSString *)keychainAccountName
{
	return [NSString stringWithFormat:@"%@ (%@)", self.UID, self.internalObjectID];
}

- (NSString *)storedToken
{
	return [[AIKeychain defaultKeychain_error:NULL] findGenericPasswordForService:DISCORD_KEYCHAIN_SERVICE
	                                                                      account:[self keychainAccountName]
	                                                                 keychainItem:NULL
	                                                                        error:NULL];
}

- (void)setStoredToken:(NSString *)token
{
	AIKeychain *keychain = [AIKeychain defaultKeychain_error:NULL];

	// Delete before adding; otherwise we just get errSecDuplicateItem
	[keychain deleteGenericPasswordForService:DISCORD_KEYCHAIN_SERVICE account:[self keychainAccountName] error:NULL];
	if ([token length]) {
		[keychain addGenericPassword:token
		                  forService:DISCORD_KEYCHAIN_SERVICE
		                     account:[self keychainAccountName]
		                keychainItem:NULL
		                       error:NULL];
	}
}

#pragma mark Connecting

- (void)configurePurpleAccount
{
	[super configurePurpleAccount];

	// purple-discord opens a server channel on every message in it when it considers the server
	// small, judging by the members it has seen; right after login that is few for any server, so a
	// busy server floods Adium with chat windows and history downloads until it freezes. Only open
	// server channels when mentioned; direct and group messages still open as usual.
	purple_account_set_int(account, "large-channel-count", 0);

	// purple-discord adds every channel to libpurple's buddy list, which Adium never shows, and
	// its find_blist_chat looks chats up by channel ID; Adium's chat opening skips the join for
	// any chat found there, so channels could never be joined from Join Group Chat.
	purple_account_set_bool(account, "populate-blist", FALSE);
	removeBlistChatsForAccount(account);

	NSString *token = nil;
	if (looksLikeToken(password)) {
		token = password;
		usedStoredToken = NO;
	} else {
		token = [self storedToken];
		usedStoredToken = ([token length] > 0);
	}

	// With nothing to supply, leave alone any token the plugin got earlier in this session, so a
	// reconnect after a dropped gateway connection doesn't redo the password and 2FA login.
	if ([token length])
		purple_account_set_string(account, "token", [token UTF8String]);

	const char *currentToken = purple_account_get_string(account, "token", NULL);
	AILog(@"Discord: connecting %@ with %@", self.UID,
	      ((currentToken && *currentToken) ? (looksLikeToken(password) ? @"token from password field" : @"saved token")
	                                       : @"email and password"));
}

// Keep the token issued by an email/password login for next time
- (void)saveIssuedToken
{
	if (looksLikeToken(password))
		return;

	const char *token = purple_account_get_string(account, "token", NULL);
	if (token && *token) {
		NSString *newToken = [NSString stringWithUTF8String:token];
		if (![newToken isEqualToString:[self storedToken]])
			[self setStoredToken:newToken];
		usedStoredToken = YES;
	}
}

- (void)didConnect
{
	[self saveIssuedToken];
	[super didConnect];
}

- (void)accountConnectionReportDisconnect:(NSString *)text withReason:(PurpleConnectionError)reason
{
	// purple-discord clears "token" when the gateway rejects it (close code 4004) and reports a
	// network error, which Adium would answer by reconnecting with the same token forever.
	const char *token = purple_account_get_string(account, "token", NULL);
	if (!(token && *token) && reason == PURPLE_CONNECTION_ERROR_NETWORK_ERROR &&
	    (usedStoredToken || looksLikeToken(password))) {
		AILog(@"Discord: token for %@ was rejected; forgetting it", self.UID);
		[self setStoredToken:nil];
		usedStoredToken = NO;
		reason = PURPLE_CONNECTION_ERROR_AUTHENTICATION_FAILED;
	} else if (reason == PURPLE_CONNECTION_ERROR_AUTHENTICATION_FAILED &&
	           ([text rangeOfString:@"two-factor" options:NSCaseInsensitiveSearch].location != NSNotFound ||
	            [text rangeOfString:@"2FA"].location != NSNotFound)) {
		// A rejected or cancelled 2FA code is not a wrong password: as an authentication failure,
		// Adium would forget the password and immediately start over. Stop and show the error.
		reason = PURPLE_CONNECTION_ERROR_OTHER_ERROR;
	} else {
		// Logged in, but the gateway connection failed before Adium saw us connect
		[self saveIssuedToken];
	}

	[super accountConnectionReportDisconnect:text withReason:reason];
}

#pragma mark Chats

// Server channels would otherwise all be titled by their bare name ("general")
- (void)updateTitle:(NSString *)inTitle forChat:(AIChat *)chat
{
	PurpleConnection *pc = purple_account_get_connection(account);
	gchar *title = ((pc && chat.name) ? discord_adium_get_channel_title(pc, [chat.name UTF8String]) : NULL);

	if (title) {
		NSString *serverTitle = [NSString stringWithUTF8String:title];
		if (serverTitle)
			inTitle = serverTitle;
		g_free(title);
	}

	[super updateTitle:inTitle forChat:chat];
}

#pragma mark Status

- (const char *)purpleStatusIDForStatus:(AIStatus *)statusState arguments:(NSMutableDictionary *)arguments
{
	switch (statusState.statusType) {
		case AIAvailableStatusType:
			return "online";
		case AIAwayStatusType:
			if ([statusState.statusName isEqualToString:STATUS_NAME_DND])
				return "dnd";
			return "idle";
		case AIInvisibleStatusType:
			return "set-invisible";
		case AIOfflineStatusType:
			return "offline";
	}

	return [super purpleStatusIDForStatus:statusState arguments:arguments];
}

@end
