#import "PanelController.h"
#import "BackgroundView.h"
#import "StatusItemView.h"
#import "MenubarController.h"

#include <sys/mount.h>

#import "DiskArbitrationPrivateFunctions.h"

#define shouldBeEjectedWhenMountedKey @"shouldBeEjectedWhenMounted"


#define OPEN_DURATION .15
#define CLOSE_DURATION .1

#define SEARCH_INSET 17

#define POPUP_HEIGHT 122
#define PANEL_WIDTH 280
#define MENU_ANIMATION_DURATION .1

@interface PanelController ()
@property (nonatomic, readwrite) BOOL shouldBeEjectedWhenMounted;
@property (nonatomic, strong) Disk *disk1;
@end

#pragma mark -

@implementation PanelController

@synthesize backgroundView = _backgroundView;
@synthesize delegate = _delegate;

#pragma mark -

- (id)initWithDelegate:(id<PanelControllerDelegate>)delegate
{
    self = [super initWithWindowNibName:@"Panel"];
    if (self != nil)
    {
        _delegate = delegate;
    }
    return self;
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark - disk stuff
////////////////////////////////////////////////////////////////////////

- (void)startDiskMonitoring {
    
    self.shouldBeEjectedWhenMounted = [[NSUserDefaults standardUserDefaults] boolForKey:shouldBeEjectedWhenMountedKey];
    
    [self registerSession];
    
    InitializeDiskArbitration();
    
//    [self ejectDisk:self.disk1];
}

- (BOOL)registerSession
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	[nc addObserver:self selector:@selector(diskDidAppear:) name:DADiskDidAppearNotification object:nil];
    //	[nc addObserver:self selector:@selector(diskDidDisappear:) name:DADiskDidDisappearNotification object:nil];
    [nc addObserver:self selector:@selector(diskDidChange:) name:DADiskDidChangeNotification object:nil];
    
	return YES;
}

- (void)diskDidAppear:(NSNotification *)notif
{
//    NSLog(@"diskDidAppear");
    //store in ivar
    Disk *disk = [notif object];
    if ([disk.BSDName isEqualToString:@"disk1"]) {
        self.disk1 = disk;
    }
    
    //eject if desired
    if (self.shouldBeEjectedWhenMounted && disk == self.disk1) {
        [self ejectDisk:self.disk1];
    }
}

- (void)diskDidChange:(NSNotification *)notif
{
    //store in ivar
    Disk *disk = [notif object];
//    NSLog(@"diskDidChange: %@", disk.BSDName);
    if ([disk.BSDName isEqualToString:@"disk1"]) {
        self.disk1 = disk;
    }
    else if ([disk.BSDName hasPrefix:@"disk1"]) {
        if (self.shouldBeEjectedWhenMounted) {
            [disk unmountWithOptions:kDADiskUnmountOptionForce];
            [disk.parent eject];
        }
    }
    //eject if desired
    if (self.shouldBeEjectedWhenMounted && disk == self.disk1) {
        [self ejectDisk1:nil];
    }
}

- (void)afterSystemDidWake {
    if (self.shouldBeEjectedWhenMounted) [self ejectDisk:self.disk1];
}

- (IBAction)toggleShouldBeRejected:(id)sender {
    NSButton *b = (NSButton *)sender;
    BOOL switchIsOn = b.state == NSOnState;
    self.shouldBeEjectedWhenMounted = switchIsOn;
    [[NSUserDefaults standardUserDefaults] setBool:switchIsOn forKey:shouldBeEjectedWhenMountedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (self.shouldBeEjectedWhenMounted) {
        [self ejectDisk:self.disk1];
    }
}

- (IBAction)ejectDisk1:(id)sender {
    [self ejectDisk:self.disk1];
}

- (void)ejectDisk:(Disk *)disk {
    if (disk == nil) {
//        NSLog(@"no disk");
        return;
    }
    
//    NSLog(@"is whole: %i, name: %@", [disk isWholeDisk], disk.BSDName);
    for (Disk *d in self.disk1.children) {
        [d unmountWithOptions:kDADiskUnmountOptionForce];
    }
    [disk eject];
    
//    [disk unmountWithOptions:kDADiskUnmountOptionWhole];
}

#pragma mark -

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Make a fully skinned panel
    NSPanel *panel = (id)[self window];
    [panel setAcceptsMouseMovedEvents:YES];
    [panel setLevel:NSPopUpMenuWindowLevel];
    [panel setOpaque:NO];
    [panel setBackgroundColor:[NSColor clearColor]];
    
    // Resize panel
    NSRect panelRect = [[self window] frame];
    panelRect.size.height = POPUP_HEIGHT;
    [[self window] setFrame:panelRect display:NO];
    
    NSCellStateValue buttonState = [[NSUserDefaults standardUserDefaults] boolForKey:shouldBeEjectedWhenMountedKey] ? NSOnState : NSOffState;
    _shouldBeEjectedButton.state = buttonState;
}

#pragma mark - Public accessors

- (BOOL)hasActivePanel
{
    return _hasActivePanel;
}

- (void)setHasActivePanel:(BOOL)flag
{
    if (_hasActivePanel != flag)
    {
        _hasActivePanel = flag;
        
        if (_hasActivePanel)
        {
            [self openPanel];
        }
        else
        {
            [self closePanel];
        }
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification
{
    self.hasActivePanel = NO;
}

- (void)windowDidResignKey:(NSNotification *)notification;
{
    if ([[self window] isVisible])
    {
        self.hasActivePanel = NO;
    }
}

- (void)windowDidResize:(NSNotification *)notification
{
    NSWindow *panel = [self window];
    NSRect statusRect = [self statusRectForWindow:panel];
    NSRect panelRect = [panel frame];
    
    CGFloat statusX = roundf(NSMidX(statusRect));
    CGFloat panelX = statusX - NSMinX(panelRect);
    
    self.backgroundView.arrowX = panelX;
}

#pragma mark - Public methods

- (NSRect)statusRectForWindow:(NSWindow *)window
{
    NSRect screenRect = [[[NSScreen screens] objectAtIndex:0] frame];
    NSRect statusRect = NSZeroRect;
    
    StatusItemView *statusItemView = nil;
    if ([self.delegate respondsToSelector:@selector(statusItemViewForPanelController:)])
    {
        statusItemView = [self.delegate statusItemViewForPanelController:self];
    }
    
    if (statusItemView)
    {
        statusRect = statusItemView.globalRect;
        statusRect.origin.y = NSMinY(statusRect) - NSHeight(statusRect);
    }
    else
    {
        statusRect.size = NSMakeSize(STATUS_ITEM_VIEW_WIDTH, [[NSStatusBar systemStatusBar] thickness]);
        statusRect.origin.x = roundf((NSWidth(screenRect) - NSWidth(statusRect)) / 2);
        statusRect.origin.y = NSHeight(screenRect) - NSHeight(statusRect) * 2;
    }
    return statusRect;
}

- (void)openPanel
{
    NSWindow *panel = [self window];
    
    NSRect screenRect = [[[NSScreen screens] objectAtIndex:0] frame];
    NSRect statusRect = [self statusRectForWindow:panel];

    NSRect panelRect = [panel frame];
    panelRect.size.width = PANEL_WIDTH;
    panelRect.origin.x = roundf(NSMidX(statusRect) - NSWidth(panelRect) / 2);
    panelRect.origin.y = NSMaxY(statusRect) - NSHeight(panelRect);
    
    if (NSMaxX(panelRect) > (NSMaxX(screenRect) - ARROW_HEIGHT))
        panelRect.origin.x -= NSMaxX(panelRect) - (NSMaxX(screenRect) - ARROW_HEIGHT);
    
    [NSApp activateIgnoringOtherApps:NO];
    [panel setAlphaValue:0];
    [panel setFrame:statusRect display:YES];
    [panel makeKeyAndOrderFront:nil];
    
    NSTimeInterval openDuration = OPEN_DURATION;
    
    NSEvent *currentEvent = [NSApp currentEvent];
    if ([currentEvent type] == NSLeftMouseDown)
    {
        NSUInteger clearFlags = ([currentEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask);
        BOOL shiftPressed = (clearFlags == NSShiftKeyMask);
        BOOL shiftOptionPressed = (clearFlags == (NSShiftKeyMask | NSAlternateKeyMask));
        if (shiftPressed || shiftOptionPressed)
        {
            openDuration *= 10;
            
            if (shiftOptionPressed)
                NSLog(@"Icon is at %@\n\tMenu is on screen %@\n\tWill be animated to %@",
                      NSStringFromRect(statusRect), NSStringFromRect(screenRect), NSStringFromRect(panelRect));
        }
    }
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:openDuration];
    [[panel animator] setFrame:panelRect display:YES];
    [[panel animator] setAlphaValue:1];
    [NSAnimationContext endGrouping];
    
}

- (void)closePanel
{
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:CLOSE_DURATION];
    [[[self window] animator] setAlphaValue:0];
    [NSAnimationContext endGrouping];
    
    dispatch_after(dispatch_walltime(NULL, NSEC_PER_SEC * CLOSE_DURATION * 2), dispatch_get_main_queue(), ^{
        
        [self.window orderOut:nil];
    });
}

@end
