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

@implementation ADDiscordAccount

- (const char *)protocolPlugin
{
	return DISCORD_PRPL_ID;
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

	NSString *token = nil;
	if (looksLikeToken(password)) {
		token = password;
		usedStoredToken = NO;
	} else {
		token = [self storedToken];
		usedStoredToken = ([token length] > 0);
	}

	AILog(@"Discord: connecting %@ with %@", self.UID,
	      ([token length] ? (usedStoredToken ? @"saved token" : @"token from password field") : @"email and password"));
	purple_account_set_string(account, "token", ([token length] ? [token UTF8String] : NULL));
}

- (void)didConnect
{
	// Keep the token issued by an email/password login for next time
	if (!looksLikeToken(password)) {
		const char *token = purple_account_get_string(account, "token", NULL);
		if (token && *token) {
			NSString *newToken = [NSString stringWithUTF8String:token];
			if (![newToken isEqualToString:[self storedToken]])
				[self setStoredToken:newToken];
		}
	}

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
	}

	[super accountConnectionReportDisconnect:text withReason:reason];
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
