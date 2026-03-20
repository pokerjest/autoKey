#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <unistd.h>

@interface AutoTyperController : NSObject <NSApplicationDelegate, NSTextViewDelegate>
@property (strong) NSWindow *window;
@property (strong) NSWindow *settingsWindow;
@property (strong) NSTextView *textView;
@property (strong) NSTextField *startDelayField;
@property (strong) NSTextField *lineBreakDelayField;
@property (strong) NSTextField *quickCharsPerMinuteField;
@property (strong) NSTextField *charsPerMinuteField;
@property (strong) NSTextField *varianceField;
@property (strong) NSTextField *minIntervalField;
@property (strong) NSTextField *maxIntervalField;
@property (strong) NSTextField *statusLabel;
@property (strong) NSTextField *speedSummaryLabel;
@property (strong) NSTextField *estimatedTimeLabel;
@property (strong) NSButton *smartQuotesCheckbox;
@property (strong) NSTextField *accessibilityStatusLabel;
@property (strong) NSTextField *inputMonitoringStatusLabel;
@property (strong) NSButton *startButton;
@property (strong) NSButton *stopButton;
@property (atomic, assign) BOOL isTyping;
@property (atomic, assign) BOOL stopRequested;
@property (copy) NSString *previousTypedCharacter;
@property (strong) id globalKeyMonitor;
@property (strong) id localKeyMonitor;
@end

@implementation AutoTyperController

static NSString * const kStartDelayDefaultsKey = @"startDelay";
static NSString * const kLineBreakDelayDefaultsKey = @"lineBreakDelay";
static NSString * const kCharsPerMinuteDefaultsKey = @"charsPerMinute";
static NSString * const kVarianceDefaultsKey = @"variance";
static NSString * const kMinIntervalDefaultsKey = @"minInterval";
static NSString * const kMaxIntervalDefaultsKey = @"maxInterval";
static NSString * const kSmartQuotesDefaultsKey = @"smartQuotes";

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self buildMenu];
    [self buildUI];
    [self buildSettingsWindow];
    [self loadSavedSettings];
    [self installEscapeMonitor];
    [self refreshPermissionStatus];
    [self refreshSpeedSummary];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeFirstResponder:self.textView];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self uninstallEscapeMonitor];
}

- (void)buildUI {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 860, 680)
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window center];
    [self.window setTitle:@"AutoKey Writer"];
    [self.window setMinSize:NSMakeSize(840, 660)];
    [self.window setBackgroundColor:[NSColor colorWithRed:0.96 green:0.97 blue:0.99 alpha:1.0]];

    NSView *contentView = self.window.contentView;

    NSView *heroBox = [self cardViewWithFrame:NSMakeRect(20, 590, 820, 70)
                                    fillColor:[NSColor colorWithRed:0.12 green:0.18 blue:0.32 alpha:1.0]
                                  borderColor:[NSColor colorWithRed:0.17 green:0.25 blue:0.43 alpha:1.0]];
    [contentView addSubview:heroBox];

    NSTextField *titleLabel = [self labelWithText:@"模拟手动输入到当前激活窗口" fontSize:24 weight:NSFontWeightBold];
    [titleLabel setTextColor:[NSColor whiteColor]];
    [titleLabel setFrame:NSMakeRect(24, 28, 420, 28)];
    [heroBox addSubview:titleLabel];

    NSTextField *hintLabel = [self labelWithText:@"切到起点作家助手输入框后，程序会按设定节奏逐字输入，支持中文输入与 Esc 紧急停止。" fontSize:13 weight:NSFontWeightRegular];
    [hintLabel setTextColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];
    [hintLabel setFrame:NSMakeRect(24, 10, 620, 18)];
    [heroBox addSubview:hintLabel];

    NSButton *openSettingsButton = [self actionButtonWithTitle:@"速度设置" frame:NSMakeRect(704, 20, 94, 30) action:@selector(openSettingsWindow:)];
    [heroBox addSubview:openSettingsButton];

    NSView *editorBox = [self cardViewWithFrame:NSMakeRect(20, 20, 540, 550)
                                      fillColor:[NSColor colorWithRed:1 green:1 blue:1 alpha:0.92]
                                    borderColor:[NSColor colorWithRed:0.87 green:0.89 blue:0.93 alpha:1.0]];
    [contentView addSubview:editorBox];

    NSTextField *editorTitle = [self labelWithText:@"待输入内容" fontSize:16 weight:NSFontWeightSemibold];
    [editorTitle setFrame:NSMakeRect(16, 518, 120, 22)];
    [editorBox addSubview:editorTitle];

    NSTextField *editorHint = [self labelWithText:@"在这里粘贴或输入要发送的正文。" fontSize:12 weight:NSFontWeightRegular];
    [editorHint setTextColor:[NSColor secondaryLabelColor]];
    [editorHint setFrame:NSMakeRect(16, 496, 240, 16)];
    [editorBox addSubview:editorHint];

    NSButton *clearButton = [self actionButtonWithTitle:@"清空内容" frame:NSMakeRect(430, 492, 86, 28) action:@selector(clearText:)];
    [editorBox addSubview:clearButton];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(14, 14, 512, 466)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setDrawsBackground:YES];
    [scrollView setBackgroundColor:[NSColor whiteColor]];

    self.textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 512, 466)];
    [self.textView setDelegate:self];
    [self.textView setFont:[NSFont systemFontOfSize:16]];
    [self.textView setEditable:YES];
    [self.textView setSelectable:YES];
    [self.textView setBackgroundColor:[NSColor whiteColor]];
    [self.textView setTextColor:[NSColor blackColor]];
    [self.textView setInsertionPointColor:[NSColor blackColor]];
    [self.textView setRichText:NO];
    [self.textView setImportsGraphics:NO];
    [self.textView setAllowsUndo:YES];
    [self.textView setUsesFindBar:YES];
    [self.textView setAutomaticQuoteSubstitutionEnabled:NO];
    [self.textView setAutomaticDashSubstitutionEnabled:NO];
    [self.textView setAutomaticTextReplacementEnabled:NO];
    [self.textView setAutomaticSpellingCorrectionEnabled:NO];
    [self.textView setContinuousSpellCheckingEnabled:NO];
    [scrollView setDocumentView:self.textView];
    [editorBox addSubview:scrollView];

    NSView *controlBox = [self cardViewWithFrame:NSMakeRect(580, 20, 260, 550)
                                       fillColor:[NSColor colorWithRed:1 green:1 blue:1 alpha:0.92]
                                     borderColor:[NSColor colorWithRed:0.87 green:0.89 blue:0.93 alpha:1.0]];
    [contentView addSubview:controlBox];

    NSTextField *controlTitle = [self labelWithText:@"控制台" fontSize:16 weight:NSFontWeightSemibold];
    [controlTitle setFrame:NSMakeRect(16, 518, 120, 22)];
    [controlBox addSubview:controlTitle];

    NSTextField *statusTitle = [self labelWithText:@"当前状态" fontSize:13 weight:NSFontWeightSemibold];
    [statusTitle setFrame:NSMakeRect(16, 482, 100, 18)];
    [controlBox addSubview:statusTitle];

    self.statusLabel = [self labelWithText:@"等待开始" fontSize:14 weight:NSFontWeightMedium];
    [self.statusLabel setTextColor:[NSColor systemTealColor]];
    [self.statusLabel setFrame:NSMakeRect(16, 458, 220, 20)];
    [controlBox addSubview:self.statusLabel];

    self.startButton = [self primaryButtonWithTitle:@"开始输入" frame:NSMakeRect(16, 410, 108, 34) action:@selector(startTyping:)];
    [controlBox addSubview:self.startButton];

    self.stopButton = [self actionButtonWithTitle:@"停止输入" frame:NSMakeRect(132, 410, 96, 34) action:@selector(stopTyping:)];
    [self.stopButton setEnabled:NO];
    [controlBox addSubview:self.stopButton];

    NSButton *sidebarSettingsButton = [self actionButtonWithTitle:@"打开速度设置" frame:NSMakeRect(16, 368, 132, 30) action:@selector(openSettingsWindow:)];
    [controlBox addSubview:sidebarSettingsButton];

    NSTextField *quickTitle = [self labelWithText:@"快速参数" fontSize:13 weight:NSFontWeightSemibold];
    [quickTitle setFrame:NSMakeRect(16, 326, 100, 18)];
    [controlBox addSubview:quickTitle];

    [controlBox addSubview:[self fieldLabel:@"倒计时(秒)" frame:NSMakeRect(16, 292, 96, 18)]];
    self.startDelayField = [self inputFieldWithValue:@"3" frame:NSMakeRect(124, 288, 104, 26)];
    [controlBox addSubview:self.startDelayField];

    [controlBox addSubview:[self fieldLabel:@"换行停顿" frame:NSMakeRect(16, 254, 96, 18)]];
    self.lineBreakDelayField = [self inputFieldWithValue:@"0.35" frame:NSMakeRect(124, 250, 104, 26)];
    [controlBox addSubview:self.lineBreakDelayField];

    [controlBox addSubview:[self fieldLabel:@"字/分钟" frame:NSMakeRect(16, 216, 96, 18)]];
    self.quickCharsPerMinuteField = [self inputFieldWithValue:@"220" frame:NSMakeRect(124, 212, 104, 26)];
    [controlBox addSubview:self.quickCharsPerMinuteField];

    NSTextField *summaryTitle = [self labelWithText:@"优化结果" fontSize:13 weight:NSFontWeightSemibold];
    [summaryTitle setFrame:NSMakeRect(16, 172, 100, 18)];
    [controlBox addSubview:summaryTitle];

    self.speedSummaryLabel = [self labelWithText:@"" fontSize:12 weight:NSFontWeightMedium];
    [self.speedSummaryLabel setFrame:NSMakeRect(16, 122, 220, 42)];
    [self.speedSummaryLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [self.speedSummaryLabel setUsesSingleLineMode:NO];
    [self.speedSummaryLabel setAllowsDefaultTighteningForTruncation:NO];
    [controlBox addSubview:self.speedSummaryLabel];

    self.estimatedTimeLabel = [self labelWithText:@"" fontSize:12 weight:NSFontWeightRegular];
    [self.estimatedTimeLabel setTextColor:[NSColor secondaryLabelColor]];
    [self.estimatedTimeLabel setFrame:NSMakeRect(16, 96, 220, 18)];
    [controlBox addSubview:self.estimatedTimeLabel];

    NSTextField *permTitle = [self labelWithText:@"权限状态" fontSize:13 weight:NSFontWeightSemibold];
    [permTitle setFrame:NSMakeRect(16, 62, 100, 18)];
    [controlBox addSubview:permTitle];

    self.accessibilityStatusLabel = [self labelWithText:@"辅助功能权限: 检查中" fontSize:11 weight:NSFontWeightRegular];
    [self.accessibilityStatusLabel setFrame:NSMakeRect(16, 38, 150, 16)];
    [controlBox addSubview:self.accessibilityStatusLabel];

    NSButton *openAccessibilityButton = [self actionButtonWithTitle:@"去开启" frame:NSMakeRect(170, 32, 66, 24) action:@selector(openAccessibilitySettings:)];
    [controlBox addSubview:openAccessibilityButton];

    self.inputMonitoringStatusLabel = [self labelWithText:@"输入监控权限: 检查中" fontSize:11 weight:NSFontWeightRegular];
    [self.inputMonitoringStatusLabel setFrame:NSMakeRect(16, 12, 150, 16)];
    [controlBox addSubview:self.inputMonitoringStatusLabel];

    NSButton *openInputMonitoringButton = [self actionButtonWithTitle:@"去开启" frame:NSMakeRect(170, 6, 66, 24) action:@selector(openInputMonitoringSettings:)];
    [controlBox addSubview:openInputMonitoringButton];

    NSButton *refreshButton = [self actionButtonWithTitle:@"刷新" frame:NSMakeRect(188, 484, 48, 24) action:@selector(refreshPermissions:)];
    [controlBox addSubview:refreshButton];

    [self configureLiveRefreshForField:self.startDelayField];
    [self configureLiveRefreshForField:self.lineBreakDelayField];
    [self configureLiveRefreshForField:self.quickCharsPerMinuteField];
}

- (void)buildSettingsWindow {
    self.settingsWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 430, 286)
                                                      styleMask:(NSWindowStyleMaskTitled |
                                                                 NSWindowStyleMaskClosable)
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
    [self.settingsWindow setTitle:@"速度设置"];
    [self.settingsWindow setReleasedWhenClosed:NO];
    [self.settingsWindow setBackgroundColor:[NSColor colorWithRed:0.97 green:0.98 blue:0.99 alpha:1.0]];

    NSView *contentView = self.settingsWindow.contentView;

    NSTextField *title = [self labelWithText:@"输入速度与节奏" fontSize:18 weight:NSFontWeightBold];
    [title setFrame:NSMakeRect(20, 238, 200, 24)];
    [contentView addSubview:title];

    NSTextField *hint = [self labelWithText:@"这里控制更细的速度策略，主界面只保留最常用的三个参数。" fontSize:12 weight:NSFontWeightRegular];
    [hint setTextColor:[NSColor secondaryLabelColor]];
    [hint setFrame:NSMakeRect(20, 218, 360, 16)];
    [contentView addSubview:hint];

    NSBox *panel = [self sectionBoxWithFrame:NSMakeRect(18, 18, 394, 186) title:nil];
    [contentView addSubview:panel];

    [panel.contentView addSubview:[self fieldLabel:@"每分钟输入字数" frame:NSMakeRect(16, 136, 120, 22)]];
    NSTextField *cpmField = [self inputFieldWithValue:@"220" frame:NSMakeRect(150, 134, 100, 26)];
    self.charsPerMinuteField = cpmField;
    [panel.contentView addSubview:cpmField];

    [panel.contentView addSubview:[self fieldLabel:@"速度波动比例" frame:NSMakeRect(16, 98, 120, 22)]];
    self.varianceField = [self inputFieldWithValue:@"0.22" frame:NSMakeRect(150, 96, 100, 26)];
    [panel.contentView addSubview:self.varianceField];

    NSTextField *varianceHint = [self labelWithText:@"例如 0.22 表示在基础速度上下约 22% 浮动，更像人工输入。" fontSize:12 weight:NSFontWeightRegular];
    [varianceHint setTextColor:[NSColor secondaryLabelColor]];
    [varianceHint setFrame:NSMakeRect(16, 74, 360, 16)];
    [panel.contentView addSubview:varianceHint];

    [panel.contentView addSubview:[self fieldLabel:@"最小间隔兜底(秒)" frame:NSMakeRect(16, 40, 120, 22)]];
    self.minIntervalField = [self inputFieldWithValue:@"0.05" frame:NSMakeRect(150, 38, 100, 26)];
    [panel.contentView addSubview:self.minIntervalField];

    [panel.contentView addSubview:[self fieldLabel:@"最大间隔兜底(秒)" frame:NSMakeRect(16, 8, 120, 22)]];
    self.maxIntervalField = [self inputFieldWithValue:@"0.40" frame:NSMakeRect(150, 6, 100, 26)];
    [panel.contentView addSubview:self.maxIntervalField];

    self.smartQuotesCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(264, 96, 114, 24)];
    [self.smartQuotesCheckbox setButtonType:NSSwitchButton];
    [self.smartQuotesCheckbox setTitle:@"智能引号修正"];
    [self.smartQuotesCheckbox setState:NSControlStateValueOff];
    [panel.contentView addSubview:self.smartQuotesCheckbox];

    NSButton *doneButton = [self primaryButtonWithTitle:@"完成" frame:NSMakeRect(314, 12, 80, 30) action:@selector(closeSettingsWindow:)];
    [panel.contentView addSubview:doneButton];

    [self configureLiveRefreshForField:self.charsPerMinuteField];
    [self configureLiveRefreshForField:self.varianceField];
    [self configureLiveRefreshForField:self.minIntervalField];
    [self configureLiveRefreshForField:self.maxIntervalField];
}

- (void)buildMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"AutoKey Writer"];
    [appMenu addItemWithTitle:@"About AutoKey Writer" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Hide AutoKey Writer" action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *hideOthers = [appMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    [hideOthers setKeyEquivalentModifierMask:(NSEventModifierFlagCommand | NSEventModifierFlagOption)];
    [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit AutoKey Writer" action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenuItem setSubmenu:appMenu];

    NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:editMenuItem];

    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [editMenuItem setSubmenu:editMenu];

    [NSApp setMainMenu:mainMenu];
}

- (void)installEscapeMonitor {
    __weak typeof(self) weakSelf = self;
    self.globalKeyMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *event) {
        [weakSelf handleEscapeEvent:event];
    }];
    self.localKeyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent *event) {
        if ([weakSelf handleEscapeEvent:event]) {
            return nil;
        }
        return event;
    }];
}

- (void)uninstallEscapeMonitor {
    if (self.globalKeyMonitor != nil) {
        [NSEvent removeMonitor:self.globalKeyMonitor];
        self.globalKeyMonitor = nil;
    }
    if (self.localKeyMonitor != nil) {
        [NSEvent removeMonitor:self.localKeyMonitor];
        self.localKeyMonitor = nil;
    }
}

- (BOOL)handleEscapeEvent:(NSEvent *)event {
    if (!self.isTyping) {
        return NO;
    }
    if (event.type == NSEventTypeKeyDown && event.keyCode == 53) {
        self.stopRequested = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setStatus:@"检测到 Esc，正在停止"];
        });
        return YES;
    }
    return NO;
}

- (NSTextField *)labelWithText:(NSString *)text fontSize:(CGFloat)fontSize weight:(CGFloat)weight {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [label setEditable:NO];
    [label setBordered:NO];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setStringValue:text];
    [label setFont:[NSFont systemFontOfSize:fontSize weight:weight]];
    [label setTextColor:[NSColor colorWithRed:0.10 green:0.14 blue:0.22 alpha:1.0]];
    return label;
}

- (NSTextField *)fieldLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [self labelWithText:text fontSize:13 weight:NSFontWeightRegular];
    [label setFrame:frame];
    return label;
}

- (NSTextField *)inputFieldWithValue:(NSString *)value frame:(NSRect)frame {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    [field setStringValue:value];
    [field setTextColor:[NSColor blackColor]];
    [field setBackgroundColor:[NSColor whiteColor]];
    [field setDrawsBackground:YES];
    [field setBordered:YES];
    [field setBezeled:YES];
    [field setFocusRingType:NSFocusRingTypeExterior];
    return field;
}

- (void)configureLiveRefreshForField:(NSTextField *)field {
    [field setTarget:self];
    [field setAction:@selector(handleLiveFieldChange:)];
}

- (NSBox *)sectionBoxWithFrame:(NSRect)frame title:(NSString *)title {
    NSBox *box = [[NSBox alloc] initWithFrame:frame];
    [box setBoxType:NSBoxCustom];
    [box setTransparent:NO];
    [box setCornerRadius:16];
    [box setFillColor:[NSColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.92]];
    [box setBorderColor:[NSColor colorWithRed:0.87 green:0.89 blue:0.93 alpha:1.0]];
    [box setBorderWidth:1];
    if (title != nil) {
        [box setTitle:title];
    }
    return box;
}

- (NSView *)cardViewWithFrame:(NSRect)frame fillColor:(NSColor *)fillColor borderColor:(NSColor *)borderColor {
    NSView *view = [[NSView alloc] initWithFrame:frame];
    [view setWantsLayer:YES];
    view.layer.cornerRadius = 16;
    view.layer.backgroundColor = fillColor.CGColor;
    view.layer.borderWidth = 1;
    view.layer.borderColor = borderColor.CGColor;
    return view;
}

- (NSButton *)actionButtonWithTitle:(NSString *)title frame:(NSRect)frame action:(SEL)action {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    [button setTitle:title];
    [button setBezelStyle:NSBezelStyleRounded];
    [button setTarget:self];
    [button setAction:action];
    [button setAttributedTitle:[[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: [NSColor colorWithRed:0.16 green:0.20 blue:0.30 alpha:1.0],
        NSFontAttributeName: [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold]
    }]];
    return button;
}

- (NSButton *)primaryButtonWithTitle:(NSString *)title frame:(NSRect)frame action:(SEL)action {
    NSButton *button = [self actionButtonWithTitle:title frame:frame action:action];
    [button setBezelStyle:NSBezelStyleRegularSquare];
    [button setWantsLayer:YES];
    button.layer.cornerRadius = 8;
    button.layer.backgroundColor = [NSColor colorWithRed:0.12 green:0.42 blue:0.86 alpha:1.0].CGColor;
    [button setAttributedTitle:[[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: [NSColor whiteColor],
        NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold]
    }]];
    return button;
}

- (void)clearText:(id)sender {
    (void)sender;
    [self.textView setString:@""];
    [self setStatus:@"内容已清空"];
    [self refreshSpeedSummary];
}

- (void)handleLiveFieldChange:(id)sender {
    (void)sender;
    [self saveCurrentSettings];
    [self refreshSpeedSummary];
}

- (void)openSettingsWindow:(id)sender {
    (void)sender;
    [self.charsPerMinuteField setStringValue:self.quickCharsPerMinuteField.stringValue];
    [self.settingsWindow center];
    [self.settingsWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)closeSettingsWindow:(id)sender {
    (void)sender;
    [self.quickCharsPerMinuteField setStringValue:self.charsPerMinuteField.stringValue];
    [self saveCurrentSettings];
    [self refreshSpeedSummary];
    [self.settingsWindow orderOut:nil];
}

- (void)refreshPermissions:(id)sender {
    (void)sender;
    [self refreshPermissionStatus];
    [self setStatus:@"权限状态已刷新"];
}

- (void)openAccessibilitySettings:(id)sender {
    (void)sender;
    [self openSystemSettingsURLStrings:@[
        @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        @"x-apple.systempreferences:com.apple.preference.security?Privacy"
    ] fallbackMessage:@"已尝试打开“辅助功能”设置"];
}

- (void)openInputMonitoringSettings:(id)sender {
    (void)sender;
    [self openSystemSettingsURLStrings:@[
        @"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
        @"x-apple.systempreferences:com.apple.preference.security?Privacy"
    ] fallbackMessage:@"已尝试打开“输入监控”设置"];
}

- (void)stopTyping:(id)sender {
    (void)sender;
    self.stopRequested = YES;
    [self setStatus:@"正在停止"];
}

- (void)startTyping:(id)sender {
    (void)sender;
    [self refreshPermissionStatus];
    [self refreshSpeedSummary];
    if (self.isTyping) {
        [self setStatus:@"当前已经在输入中"];
        return;
    }

    NSString *content = [[self.textView string] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (content.length == 0) {
        [self setStatus:@"请先输入要发送的内容"];
        return;
    }

    double startDelay = [self.startDelayField doubleValue];
    double lineBreakDelay = [self.lineBreakDelayField doubleValue];
    double charsPerMinute = [self.quickCharsPerMinuteField doubleValue];
    double variance = [self.varianceField doubleValue];
    double minFloor = [self.minIntervalField doubleValue];
    double maxCeiling = [self.maxIntervalField doubleValue];

    if (startDelay < 0 || lineBreakDelay < 0 || charsPerMinute <= 0 || variance < 0 || variance > 0.9 || minFloor < 0 || maxCeiling < minFloor) {
        [self setStatus:@"参数无效，请检查数字范围"];
        return;
    }

    double baseInterval = 60.0 / charsPerMinute;
    double minInterval = MAX(minFloor, baseInterval * (1.0 - variance));
    double maxInterval = MIN(maxCeiling, baseInterval * (1.0 + variance));
    if (maxInterval < minInterval) {
        maxInterval = minInterval;
    }

    self.isTyping = YES;
    self.stopRequested = NO;
    self.previousTypedCharacter = nil;
    [self saveCurrentSettings];
    [self.startButton setEnabled:NO];
    [self.stopButton setEnabled:YES];
    [self setStatus:[NSString stringWithFormat:@"%.1f 秒后开始，请切到目标输入框", startDelay]];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self runTypingWithContent:content
                        startDelay:startDelay
                       minInterval:minInterval
                       maxInterval:maxInterval
                    lineBreakDelay:lineBreakDelay];
    });
}

- (void)refreshPermissionStatus {
    BOOL hasAccessibility = AXIsProcessTrusted();
    BOOL hasInputMonitoring = [self hasInputMonitoringPermission];
    [self.accessibilityStatusLabel setStringValue:[NSString stringWithFormat:@"辅助功能权限: %@", hasAccessibility ? @"已开启" : @"未开启"]];
    [self.accessibilityStatusLabel setTextColor:hasAccessibility ? [NSColor systemGreenColor] : [NSColor systemRedColor]];
    [self.inputMonitoringStatusLabel setStringValue:[NSString stringWithFormat:@"输入监控权限: %@", hasInputMonitoring ? @"已开启" : @"未开启"]];
    [self.inputMonitoringStatusLabel setTextColor:hasInputMonitoring ? [NSColor systemGreenColor] : [NSColor systemRedColor]];
}

- (void)refreshSpeedSummary {
    double charsPerMinute = [self.quickCharsPerMinuteField doubleValue];
    double variance = [self.varianceField doubleValue];
    double baseInterval = charsPerMinute > 0 ? 60.0 / charsPerMinute : 0;
    NSString *summary = [NSString stringWithFormat:@"当前节奏: %.0f 字/分钟 | 基础间隔 %.2f 秒/字 | 波动 %.0f%% | Esc 可随时停止",
                         charsPerMinute, baseInterval, variance * 100.0];
    [self.speedSummaryLabel setStringValue:summary];
    [self.estimatedTimeLabel setStringValue:[self estimatedTimeText]];
}

- (NSString *)estimatedTimeText {
    NSString *content = self.textView.string ?: @"";
    NSUInteger count = [[content stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] length];
    double charsPerMinute = [self.quickCharsPerMinuteField doubleValue];
    double startDelay = [self.startDelayField doubleValue];
    double lineBreakDelay = [self.lineBreakDelayField doubleValue];
    if (count == 0 || charsPerMinute <= 0) {
        return @"预计完成时间: 等待输入内容";
    }

    NSUInteger lineBreakCount = 0;
    for (NSUInteger i = 0; i < content.length; i++) {
        if ([content characterAtIndex:i] == '\n') {
            lineBreakCount += 1;
        }
    }

    double estimatedSeconds = startDelay + ((double)count * 60.0 / charsPerMinute) + ((double)lineBreakCount * lineBreakDelay);
    return [NSString stringWithFormat:@"预计完成时间: %@", [self formattedDuration:estimatedSeconds]];
}

- (NSString *)formattedDuration:(double)seconds {
    NSInteger rounded = (NSInteger)llround(seconds);
    NSInteger minutes = rounded / 60;
    NSInteger remain = rounded % 60;
    if (minutes <= 0) {
        return [NSString stringWithFormat:@"%ld 秒", (long)MAX(remain, 1)];
    }
    return [NSString stringWithFormat:@"%ld 分 %ld 秒", (long)minutes, (long)remain];
}

- (void)loadSavedSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *startDelay = [defaults stringForKey:kStartDelayDefaultsKey];
    NSString *lineBreakDelay = [defaults stringForKey:kLineBreakDelayDefaultsKey];
    NSString *charsPerMinute = [defaults stringForKey:kCharsPerMinuteDefaultsKey];
    NSString *variance = [defaults stringForKey:kVarianceDefaultsKey];
    NSString *minInterval = [defaults stringForKey:kMinIntervalDefaultsKey];
    NSString *maxInterval = [defaults stringForKey:kMaxIntervalDefaultsKey];
    BOOL smartQuotes = [defaults boolForKey:kSmartQuotesDefaultsKey];

    if (startDelay.length > 0) {
        [self.startDelayField setStringValue:startDelay];
    }
    if (lineBreakDelay.length > 0) {
        [self.lineBreakDelayField setStringValue:lineBreakDelay];
    }
    if (charsPerMinute.length > 0) {
        [self.quickCharsPerMinuteField setStringValue:charsPerMinute];
        [self.charsPerMinuteField setStringValue:charsPerMinute];
    }
    if (variance.length > 0) {
        [self.varianceField setStringValue:variance];
    }
    if (minInterval.length > 0) {
        [self.minIntervalField setStringValue:minInterval];
    }
    if (maxInterval.length > 0) {
        [self.maxIntervalField setStringValue:maxInterval];
    }
    [self.smartQuotesCheckbox setState:smartQuotes ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)saveCurrentSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.startDelayField.stringValue forKey:kStartDelayDefaultsKey];
    [defaults setObject:self.lineBreakDelayField.stringValue forKey:kLineBreakDelayDefaultsKey];
    [defaults setObject:self.quickCharsPerMinuteField.stringValue forKey:kCharsPerMinuteDefaultsKey];
    [defaults setObject:self.varianceField.stringValue forKey:kVarianceDefaultsKey];
    [defaults setObject:self.minIntervalField.stringValue forKey:kMinIntervalDefaultsKey];
    [defaults setObject:self.maxIntervalField.stringValue forKey:kMaxIntervalDefaultsKey];
    [defaults setBool:(self.smartQuotesCheckbox.state == NSControlStateValueOn) forKey:kSmartQuotesDefaultsKey];
}

- (void)textDidChange:(NSNotification *)notification {
    (void)notification;
    [self refreshSpeedSummary];
}

- (BOOL)hasInputMonitoringPermission {
    if (@available(macOS 10.15, *)) {
        return CGPreflightListenEventAccess();
    }
    return YES;
}

- (void)openSystemSettingsURLStrings:(NSArray<NSString *> *)urlStrings fallbackMessage:(NSString *)message {
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    for (NSString *urlString in urlStrings) {
        NSURL *url = [NSURL URLWithString:urlString];
        if (url != nil && [workspace openURL:url]) {
            [self setStatus:message];
            return;
        }
    }
    [self showAlertWithTitle:@"无法打开系统设置" message:@"请手动前往“系统设置 -> 隐私与安全性”中调整权限。"];
}

- (void)runTypingWithContent:(NSString *)content
                  startDelay:(double)startDelay
                 minInterval:(double)minInterval
                 maxInterval:(double)maxInterval
              lineBreakDelay:(double)lineBreakDelay {
    if (![self sleepWithCancel:startDelay]) {
        [self finishTypingWithStatus:@"已停止"];
        return;
    }

    NSString *sanitizedContent = [self contentByRemovingBlankLines:content];

    NSMutableArray<NSString *> *characters = [NSMutableArray array];
    [sanitizedContent enumerateSubstringsInRange:NSMakeRange(0, sanitizedContent.length)
                                options:NSStringEnumerationByComposedCharacterSequences
                             usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substringRange;
        (void)enclosingRange;
        (void)stop;
        if (substring != nil) {
            [characters addObject:substring];
        }
    }];

    NSUInteger total = characters.count;
    for (NSUInteger index = 0; index < total; index++) {
        if (self.stopRequested) {
            [self finishTypingWithStatus:@"已停止"];
            return;
        }

        NSString *character = characters[index];
        NSError *error = nil;
        if (![self sendCharacter:character error:&error]) {
            NSString *message = error.localizedDescription ?: @"未知错误";
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showAlertWithTitle:@"发送失败" message:message];
            });
            [self finishTypingWithStatus:@"发送失败，请检查辅助功能权限"];
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setStatus:[NSString stringWithFormat:@"输入中 %lu/%lu", (unsigned long)(index + 1), (unsigned long)total]];
        });

        double delay = [self randomBetween:minInterval max:maxInterval];
        if ([character isEqualToString:@"\n"]) {
            delay += lineBreakDelay;
            if ([self.previousTypedCharacter isEqualToString:@"\n"]) {
                delay += 0.25;
            }
        }

        self.previousTypedCharacter = character;

        if (![self sleepWithCancel:delay]) {
            [self finishTypingWithStatus:@"已停止"];
            return;
        }
    }

    [self finishTypingWithStatus:@"输入完成"];
}

- (NSString *)contentByRemovingBlankLines:(NSString *)content {
    NSArray<NSString *> *lines = [content componentsSeparatedByString:@"\n"];
    NSMutableArray<NSString *> *filtered = [NSMutableArray array];

    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length == 0) {
            continue;
        }
        [filtered addObject:line];
    }

    return [filtered componentsJoinedByString:@"\n"];
}

- (double)randomBetween:(double)min max:(double)max {
    if (max <= min) {
        return min;
    }
    uint32_t randomValue = arc4random_uniform(UINT32_MAX);
    double ratio = (double)randomValue / (double)UINT32_MAX;
    return min + (max - min) * ratio;
}

- (BOOL)sleepWithCancel:(double)seconds {
    if (seconds <= 0) {
        return !self.stopRequested;
    }
    double elapsed = 0;
    while (elapsed < seconds) {
        if (self.stopRequested) {
            return NO;
        }
        usleep(20000);
        elapsed += 0.02;
    }
    return !self.stopRequested;
}

- (BOOL)sendCharacter:(NSString *)character error:(NSError **)error {
    BOOL shouldCorrectCursor = NO;

    if ([character isEqualToString:@"\n"]) {
        return [self postKeyCode:36 error:error];
    }
    if ([character isEqualToString:@"\t"]) {
        return [self postKeyCode:48 error:error];
    }
    if ([character isEqualToString:@"\""] && self.smartQuotesCheckbox.state == NSControlStateValueOn) {
        return [self pasteLiteralText:@"\"" error:error];
    }
    if ([character isEqualToString:@"("] ||
               [character isEqualToString:@"["] ||
               [character isEqualToString:@"{"]) {
        shouldCorrectCursor = YES;
    }

    BOOL ok = [self postUnicodeString:character error:error];
    if (!ok) {
        return NO;
    }

    if (shouldCorrectCursor) {
        usleep(120000);
        return [self postKeyCode:123 error:error];
    }

    return YES;
}

- (BOOL)postKeyCode:(CGKeyCode)keyCode error:(NSError **)error {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (source == NULL) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"AutoKeyWriter" code:1 userInfo:@{NSLocalizedDescriptionKey: @"无法创建键盘事件源"}];
        }
        return NO;
    }

    CGEventRef keyDown = CGEventCreateKeyboardEvent(source, keyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(source, keyCode, false);
    if (keyDown == NULL || keyUp == NULL) {
        if (keyDown != NULL) {
            CFRelease(keyDown);
        }
        if (keyUp != NULL) {
            CFRelease(keyUp);
        }
        CFRelease(source);
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"AutoKeyWriter" code:2 userInfo:@{NSLocalizedDescriptionKey: @"无法创建按键事件"}];
        }
        return NO;
    }

    CGEventPost(kCGHIDEventTap, keyDown);
    CGEventPost(kCGHIDEventTap, keyUp);
    CFRelease(keyDown);
    CFRelease(keyUp);
    CFRelease(source);
    return YES;
}


- (BOOL)postUnicodeString:(NSString *)text error:(NSError **)error {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (source == NULL) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"AutoKeyWriter" code:3 userInfo:@{NSLocalizedDescriptionKey: @"无法创建 Unicode 事件源"}];
        }
        return NO;
    }

    UniChar buffer[8];
    NSUInteger length = [text length];
    if (length > 8) {
        length = 8;
    }
    [text getCharacters:buffer range:NSMakeRange(0, length)];

    CGEventRef keyDown = CGEventCreateKeyboardEvent(source, 0, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(source, 0, false);
    if (keyDown == NULL || keyUp == NULL) {
        if (keyDown != NULL) {
            CFRelease(keyDown);
        }
        if (keyUp != NULL) {
            CFRelease(keyUp);
        }
        CFRelease(source);
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"AutoKeyWriter" code:4 userInfo:@{NSLocalizedDescriptionKey: @"无法创建 Unicode 按键事件"}];
        }
        return NO;
    }

    CGEventKeyboardSetUnicodeString(keyDown, (UniCharCount)length, buffer);
    CGEventKeyboardSetUnicodeString(keyUp, (UniCharCount)length, buffer);
    CGEventPost(kCGHIDEventTap, keyDown);
    CGEventPost(kCGHIDEventTap, keyUp);
    CFRelease(keyDown);
    CFRelease(keyUp);
    CFRelease(source);
    return YES;
}

- (BOOL)pasteLiteralText:(NSString *)text error:(NSError **)error {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray<NSPasteboardItem *> *existingItems = [pasteboard.pasteboardItems copy] ?: @[];

    [pasteboard clearContents];
    BOOL wrote = [pasteboard setString:text forType:NSPasteboardTypeString];
    if (!wrote) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"AutoKeyWriter" code:7 userInfo:@{NSLocalizedDescriptionKey: @"无法写入剪贴板"}];
        }
        return NO;
    }

    BOOL ok = [self postModifiedKeyCode:9 flags:kCGEventFlagMaskCommand error:error];

    [pasteboard clearContents];
    if (existingItems.count > 0) {
        [pasteboard writeObjects:existingItems];
    }

    return ok;
}

- (BOOL)postModifiedKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags error:(NSError **)error {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (source == NULL) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"AutoKeyWriter" code:8 userInfo:@{NSLocalizedDescriptionKey: @"无法创建组合键事件源"}];
        }
        return NO;
    }

    CGEventRef keyDown = CGEventCreateKeyboardEvent(source, keyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(source, keyCode, false);
    if (keyDown == NULL || keyUp == NULL) {
        if (keyDown != NULL) {
            CFRelease(keyDown);
        }
        if (keyUp != NULL) {
            CFRelease(keyUp);
        }
        CFRelease(source);
        if (error != NULL) {
            *error = [NSError errorWithDomain:@"AutoKeyWriter" code:9 userInfo:@{NSLocalizedDescriptionKey: @"无法创建组合键事件"}];
        }
        return NO;
    }

    CGEventSetFlags(keyDown, flags);
    CGEventSetFlags(keyUp, flags);
    CGEventPost(kCGHIDEventTap, keyDown);
    CGEventPost(kCGHIDEventTap, keyUp);

    CFRelease(keyDown);
    CFRelease(keyUp);
    CFRelease(source);
    return YES;
}

- (void)finishTypingWithStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isTyping = NO;
        self.stopRequested = NO;
        [self.startButton setEnabled:YES];
        [self.stopButton setEnabled:NO];
        [self setStatus:status];
    });
}

- (void)setStatus:(NSString *)status {
    [self.statusLabel setStringValue:status];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert addButtonWithTitle:@"知道了"];
    [alert runModal];
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        [NSApplication sharedApplication];
        AutoTyperController *delegate = [[AutoTyperController alloc] init];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp setDelegate:delegate];
        [NSApp run];
    }
    return 0;
}
