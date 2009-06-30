/* Copyright © 2007-2008, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY BEN TRASK ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL BEN TRASK BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "OPBrowserController.h"
#import "NSMenuAdditions.h"
#import "NSObjectAdditions.h"

static Class OPOWBrowserController;
static void (*OPBrowserControllerSetLinkHoverTextOriginal)(id, SEL, NSString *);
static BOOL (*OPBrowserControllerValidateMenuItemOriginal)(id, SEL, NSMenuItem *);

static NSMenu *OPRSSMenu;

@interface NSObject(OP_OWMethods)

// OWController
+ (id)sharedController;
- (id)openAddressInPreferredWindow:(id)fp8;

// OWBrowserController
- (NSString *)documentTitle;
- (void)setWindowTitle:(NSString *)aString;
- (BOOL)statusBarVisible;
- (id)activeTab;
- (void)setLinkHoverText:(NSString *)aString;

// OWTab
- (id)rssFeeds;
- (id)preferenceForKey:(id)aString;

// OWSitePreference
- (BOOL)boolValue;
- (void)setBoolValue:(BOOL)flag;

// OWBookmarks
+ (id)favoritesBookmarks;
- (id)topBookmark;

// OWBookmark
- (NSArray *)children;
- (id)address;

@end

@implementation OPBrowserController

#pragma mark +OPBrowserController

+ (id)activeTabForBrowserController:(id)browserController
{
	return [browserController respondsToSelector:@selector(activeTab)] ? [browserController activeTab] : nil;
}
+ (id)javaScriptPreferenceForBrowserController:(id)browserController
{
	id const tab = [self activeTabForBrowserController:browserController];
	if(![tab respondsToSelector:@selector(preferenceForKey:)]) return nil;
	return [tab preferenceForKey:@"JavaScriptEnabled"];
}

#pragma mark +NSObject

+ (void)load
{
	if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4) return;
	OPOWBrowserController = NSClassFromString(@"OWBrowserController");
	OPBrowserControllerSetLinkHoverTextOriginal = (void (*)(id, SEL, NSString *))[OPOWBrowserController OP_useImplementationFromClass:self forSelector:@selector(setLinkHoverText:)];

	NSMenu *menu = nil;
	NSUInteger index = 0;
	NSBundle *const bundle = [NSBundle bundleForClass:self];
	if([[NSApp mainMenu] OP_getMenu:&menu index:&index ofItemWithTarget:nil action:@selector(toggleSitePreferences:)]) {
		NSMenuItem *const jsItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Turn JavaScript On", nil, bundle, nil) action:@selector(OP_toggleJavaScriptEnabled:) keyEquivalent:@"x"] autorelease];
		[jsItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
		[menu insertItem:jsItem atIndex:index + 1];
		OPBrowserControllerValidateMenuItemOriginal = (BOOL (*)(id, SEL, NSMenuItem *))[OPOWBrowserController OP_useImplementationFromClass:self forSelector:@selector(validateMenuItem:)];
		(void)[OPOWBrowserController OP_useImplementationFromClass:self forSelector:@selector(OP_toggleJavaScriptEnabled:)];
	}
	if([[NSApp mainMenu] OP_getMenu:&menu index:&index ofItemWithTarget:nil action:@selector(openNextChangedBookmark:)]) {
		NSString *const title = NSLocalizedStringFromTableInBundle(@"Add News Feed", nil, bundle, nil);
		NSMenuItem *const RSSItem = [[[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""] autorelease];
		OPRSSMenu = [[NSMenu alloc] initWithTitle:title];
		[OPRSSMenu setDelegate:self];
		[RSSItem setSubmenu:OPRSSMenu];
		[menu insertItem:RSSItem atIndex:index];
	}
	if([[NSApp mainMenu] OP_getMenu:&menu index:&index ofItemWithTarget:nil action:@selector(openAllChangedBookmarks:)]) {
		NSMenuItem *const randomItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Open Random Favorite", nil, bundle, nil) action:@selector(OP_openRandomBookmark:) keyEquivalent:@""] autorelease];
		[menu insertItem:randomItem atIndex:index + 1];
		(void)[OPOWBrowserController OP_useImplementationFromClass:self forSelector:@selector(OP_openRandomBookmark:)];
		srandomdev();
	}
}

#pragma mark +NSObject(NSMenuDelegate)

+ (void)menuNeedsUpdate:(NSMenu *)menu
{
	while([OPRSSMenu numberOfItems]) [OPRSSMenu removeItemAtIndex:0];
	id const tab = [OPBrowserController activeTabForBrowserController:[[NSApp mainWindow] delegate]];
	NSArray *const feeds = [tab respondsToSelector:@selector(rssFeeds)] ? [tab rssFeeds] : nil;
	NSBundle *const bundle = [NSBundle bundleForClass:self];
	for(NSDictionary *const feed in feeds) {
		NSString *const title = [feed respondsToSelector:@selector(objectForKey:)] ? [feed objectForKey:@"title"] : nil;
		NSMenuItem *const item = [[[NSMenuItem alloc] initWithTitle:(title ? title : NSLocalizedStringFromTableInBundle(@"Untitled Feed", nil, bundle, nil)) action:@selector(subscribeToRSSFeed:) keyEquivalent:@""] autorelease];
		[item setRepresentedObject:feed];
		[item setTarget:tab];
		[OPRSSMenu addItem:item];
	}
	if(![OPRSSMenu numberOfItems]) [OPRSSMenu addItem:[[[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"No Feeds", nil, bundle, nil) action:NULL keyEquivalent:@""] autorelease]];
}

#pragma mark -OPBrowserController

- (IBAction)OP_toggleJavaScriptEnabled:(id)sender
{
	id const sitePref = [OPBrowserController javaScriptPreferenceForBrowserController:self];
	if([sitePref respondsToSelector:@selector(setBoolValue:)] && [sitePref respondsToSelector:@selector(boolValue)]) [sitePref setBoolValue:![sitePref boolValue]];
	else NSBeep();
}
- (IBAction)OP_openRandomBookmark:(id)sender
{
	do {
		Class const b = NSClassFromString(@"OWBookmarks");
		if(![b respondsToSelector:@selector(favoritesBookmarks)]) break;
		id const container = [b favoritesBookmarks];
		if(![container respondsToSelector:@selector(topBookmark)]) break;
		id const topBookmark = [container topBookmark];
		if(![topBookmark respondsToSelector:@selector(children)]) break;
		NSArray *const bookmarks = [topBookmark children];
		if(![bookmarks isKindOfClass:[NSArray class]] || ![bookmarks count]) break;
		id const bookmark = [bookmarks objectAtIndex:random() % [bookmarks count]];
		if(![bookmark respondsToSelector:@selector(address)]) break;
		id const address = [(NSObject *)bookmark address];
		Class const c = NSClassFromString(@"OWController");
		if(![c respondsToSelector:@selector(sharedController)]) break;
		id const controller = [c sharedController];
		if(![controller respondsToSelector:@selector(openURL:userData:error:)]) break;
		[controller openAddressInPreferredWindow:address];
		return;
	} while(NO);
	NSBeep();
}

#pragma mark -OWBrowserController

- (void)setLinkHoverText:(NSString *)aString
{
	if([OPOWBrowserController instancesRespondToSelector:@selector(setLinkHoverText:)]) OPBrowserControllerSetLinkHoverTextOriginal(self, _cmd, aString);
	if([self respondsToSelector:@selector(setWindowTitle:)] && [self respondsToSelector:@selector(documentTitle)] && [self respondsToSelector:@selector(statusBarVisible)] && ![self statusBarVisible]) [self setWindowTitle:(aString ? aString : [self documentTitle])];
}

#pragma mark -NSObject(NSMenuValidation)

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	SEL const action = [anItem action];
	if(@selector(OP_toggleJavaScriptEnabled:) == action) {
		NSBundle *const bundle = [NSBundle bundleForClass:[OPBrowserController class]];
		id const sitePref = [OPBrowserController javaScriptPreferenceForBrowserController:self];
		[anItem setTitle:([sitePref respondsToSelector:@selector(boolValue)] && [sitePref boolValue] ? NSLocalizedStringFromTableInBundle(@"Turn JavaScript Off", nil, bundle, nil) : NSLocalizedStringFromTableInBundle(@"Turn JavaScript On", nil, bundle, nil))];
		return [self respondsToSelector:action];
	}
	if([OPOWBrowserController instancesRespondToSelector:@selector(validateMenuItem:)]) return OPBrowserControllerValidateMenuItemOriginal(self, _cmd, anItem);
	return [self respondsToSelector:action];
}

@end
