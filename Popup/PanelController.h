#import "BackgroundView.h"
#import "StatusItemView.h"

@class PanelController;

@protocol PanelControllerDelegate <NSObject>

@optional

- (StatusItemView *)statusItemViewForPanelController:(PanelController *)controller;

@end

#pragma mark -

@interface PanelController : NSWindowController <NSWindowDelegate>
{
    BOOL _hasActivePanel;
    __unsafe_unretained BackgroundView *_backgroundView;
    __unsafe_unretained id<PanelControllerDelegate> _delegate;
    __unsafe_unretained NSButton *_ejectButton;
    __unsafe_unretained NSButton *_shouldBeEjectedButton;
}

@property (nonatomic, unsafe_unretained) IBOutlet BackgroundView *backgroundView;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *ejectButton;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *shouldBeEjectedButton;

@property (nonatomic) BOOL hasActivePanel;
@property (nonatomic, unsafe_unretained, readonly) id<PanelControllerDelegate> delegate;

- (id)initWithDelegate:(id<PanelControllerDelegate>)delegate;
- (IBAction)toggleShouldBeRejected:(id)sender;
- (IBAction)ejectDisk1:(id)sender;
- (void)startDiskMonitoring;
- (void)afterSystemDidWake;
- (void)openPanel;
- (void)closePanel;

@end
