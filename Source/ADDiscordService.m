/*
 * Discord for Adium
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 */

#import "ADDiscordService.h"
#import "ADDiscordAccount.h"
#import <Adium/AISharedAdium.h>
#import <Adium/AIStatusControllerProtocol.h>
#import <AIUtilities/AIImageAdditions.h>

@implementation ADDiscordService

- (Class)accountClass
{
	return [ADDiscordAccount class];
}

- (NSString *)serviceCodeUniqueID       { return @"libpurple-discord"; }
- (NSString *)serviceID                 { return @"Discord"; }
- (NSString *)serviceClass              { return @"Discord"; }
- (NSString *)shortDescription          { return @"Discord"; }
- (NSString *)longDescription           { return @"Discord"; }
- (AIServiceImportance)serviceImportance { return AIServicePrimary; }
- (NSString *)userNameLabel             { return @"Email"; }
- (NSString *)contactUserNameLabel      { return @"Discord Username"; }
- (BOOL)caseSensitive                   { return YES; }
- (BOOL)canCreateGroupChats             { return NO; }
- (BOOL)canRegisterNewAccounts          { return NO; }
- (BOOL)supportsProxySettings           { return YES; }

- (NSImage *)defaultServiceIconOfType:(AIServiceIconType)iconType
{
	NSString *name = (iconType == AIServiceIconLarge) ? @"discord-48" : @"discord-16";
	return [NSImage imageNamed:name forClass:[self class] loadLazily:YES];
}

- (NSString *)pathForDefaultServiceIconOfType:(AIServiceIconType)iconType
{
	NSString *name = (iconType == AIServiceIconLarge) ? @"discord-48" : @"discord-16";
	return [[NSBundle bundleForClass:[self class]] pathForImageResource:name];
}

- (void)registerStatus:(NSString *)name ofType:(AIStatusType)type
{
	[adium.statusController registerStatus:name
	                       withDescription:[adium.statusController localizedDescriptionForCoreStatusName:name]
	                                ofType:type
	                            forService:self];
}

// Discord has Online, Idle, Do Not Disturb and Invisible; ADDiscordAccount maps these back.
- (void)registerStatuses
{
	[self registerStatus:STATUS_NAME_AVAILABLE ofType:AIAvailableStatusType];
	[self registerStatus:STATUS_NAME_AWAY      ofType:AIAwayStatusType];
	[self registerStatus:STATUS_NAME_DND       ofType:AIAwayStatusType];
	[self registerStatus:STATUS_NAME_INVISIBLE ofType:AIInvisibleStatusType];
}

@end
