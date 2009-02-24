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

static void (*OPBrowserControllerSetLinkHoverTextOriginal)(id, SEL, NSString *);
static BOOL (*OPBrowserControllerValidateMenuItemOriginal)(id, SEL, NSMenuItem *);

@interface NSObject(OP_OWMethods)

// OWBrowserController
- (NSString *)documentTitle;
- (void)setWindowTitle:(NSString *)aString;
- (BOOL)statusBarVisible;
- (id)activeTab;

// OWTab
- (id)preferenceForKey:(id)aString;

// OWSitePreference
- (BOOL)boolValue;
- (void)setBoolValue:(BOOL)flag;

@end

@implementation OPBrowserController

#pragma mark +OPBrowserController

+ (id)javaScriptPreferenceForBrowserController:(id)browserController
{
	if(![browserController respondsToSelector:@selector(activeTab)]) return nil;
	id const tab = [browserController activeTab];
	if(![tab respondsToSelector:@selector(preferenceForKey:)]) return nil;
	return [tab preferenceForKey:@"JavaScriptEnabled"];
}

#pragma mark +NSObject

+ (void)load
{
	if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4) return;
	OPBrowserControllerSetLinkHoverTextOriginal = (void (*)(id, SEL, NSString *))[NSClassFromString(@"OWBrowserController") OP_useImplementationFromClass:self forSelector:@selector(setLinkHoverText:)];

	NSMenu *menu = nil;
	NSUInteger index = 0;
	if([[NSApp mainMenu] OP_getMenu:&menu index:&index ofItemWithTarget:nil action:@selector(toggleSitePreferences:)]) {
		NSMenuItem *const jsItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Turn JavaScript On", nil, [NSBundle bundleForClass:self], nil) action:@selector(OP_toggleJavaScriptEnabled:) keyEquivalent:@"x"] autorelease];
		[jsItem setIndentationLevel:1];
		[jsItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
		[menu insertItem:jsItem atIndex:index + 1];
		OPBrowserControllerValidateMenuItemOriginal = (BOOL (*)(id, SEL, NSMenuItem *))[NSClassFromString(@"OWBrowserController") OP_useImplementationFromClass:self forSelector:@selector(validateMenuItem:)];
		(void)[NSClassFromString(@"OWBrowserController") OP_useImplementationFromClass:self forSelector:@selector(OP_toggleJavaScriptEnabled:)];
	}
}

#pragma mark -OPBrowserController

- (IBAction)OP_toggleJavaScriptEnabled:(id)sender
{
	id const sitePref = [OPBrowserController javaScriptPreferenceForBrowserController:self];
	if([sitePref respondsToSelector:@selector(setBoolValue:)] && [sitePref respondsToSelector:@selector(boolValue)]) [sitePref setBoolValue:![sitePref boolValue]];
	else NSBeep();
}

#pragma mark -OWBrowserController

- (void)setLinkHoverText:(NSString *)aString
{
	if(OPBrowserControllerSetLinkHoverTextOriginal) OPBrowserControllerSetLinkHoverTextOriginal(self, _cmd, aString);
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
	return OPBrowserControllerValidateMenuItemOriginal ? OPBrowserControllerValidateMenuItemOriginal(self, _cmd, anItem) : [self respondsToSelector:action];
}

@end
