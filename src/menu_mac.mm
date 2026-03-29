#import <Cocoa/Cocoa.h>
#include "menu.h"
#include "sbrvkeys.h"

static MenuResult g_result;
static bool g_pending = false;
static bool g_soundEnabled = true;
static int g_pendingKey = 0;
static NSWindow *g_helpWindow = nil;

struct ScenarioDef {
    const char *flt;
    const char *wld;
    const char *grnd;
    int rnd;
    int no_crash;
};

static const ScenarioDef missionDefs[] = {
    {"fly.flt",      "a.wld",   NULL,    0, 1},
    {"takeoff.flt",  "a.wld",   NULL,    0, 0},
    {"shoot1.flt",   "a.wld",   NULL,    0, 0},
    {"shoot2.flt",   "a.wld",   NULL,    0, 0},
    {"shoot3.flt",   "a.wld",   NULL,    0, 0},
    {"dogfight.flt", "a.wld",   NULL,    1, 0},
    {"furball.flt",  "a.wld",   "a.gru", 1, 0},
    {"melee.flt",    "a.wld",   NULL,    0, 0},
    {"migjump.flt",  "a.wld",   NULL,    0, 0},
    {"yakattak.flt", "a.wld",   NULL,    1, 0},
    {"thunder.flt",  "a.wld",   NULL,    0, 0},
    {"pistons.flt",  "a.wld",   NULL,    0, 0},
    {"gru.flt",      "gru.wld", "b.gru", 0, 0},
    {"gru2.flt",     "gru.wld", "b.gru", 0, 0},
    {"gru3.flt",     "gru.wld", "b.gru", 0, 0},
};

static const ScenarioDef demoDefs[] = {
    {"furball.flt",  "a.wld",   NULL,    0, 0},
    {"melee.flt",    "a.wld",   NULL,    0, 0},
    {"migjump.flt",  "a.wld",   NULL,    0, 0},
    {"yakattak.flt", "a.wld",   NULL,    0, 0},
    {"thunder.flt",  "a.wld",   NULL,    0, 0},
    {"pistons.flt",  "a.wld",   NULL,    0, 0},
};

static void fillResult(const ScenarioDef &s, int demo)
{
    g_result.flight_file = s.flt;
    g_result.world_file = s.wld;
    g_result.ground_file = s.grnd;
    g_result.do_random = s.rnd;
    g_result.no_crash = s.no_crash;
    g_result.demo = demo;
    g_result.want_sound = g_soundEnabled ? 1 : 0;
    g_result.quit = 0;
    g_pending = true;
}

static void sendKey(int vkey)
{
    g_pendingKey = vkey;
}

extern void sound_set_master_volume(int);
extern int sound_get_master_volume(void);

@interface MenuDelegate : NSObject
- (void)missionAction:(id)sender;
- (void)demoAction:(id)sender;
- (void)customMission:(id)sender;
- (void)viewAction:(id)sender;
- (void)toggleSound:(id)sender;
- (void)volumeUp:(id)sender;
- (void)volumeDown:(id)sender;
- (void)showHelp:(id)sender;
- (void)quitAction:(id)sender;
- (void)updateVolumeTitle;
@end

static NSMenuItem *g_volumeItem = nil;

@implementation MenuDelegate

- (void)missionAction:(id)sender {
    fillResult(missionDefs[[sender tag]], 0);
}

- (void)demoAction:(id)sender {
    fillResult(demoDefs[[sender tag]], 1);
}

- (void)customMission:(id)sender {
    (void)sender;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setTitle:@"Select Flight File"];
    [panel setAllowedFileTypes:@[@"flt"]];
    [panel setDirectoryURL:[NSURL fileURLWithPath:@"./lib"]];
    [panel setAllowsMultipleSelection:NO];

    if ([panel runModal] == NSModalResponseOK) {
        NSURL *url = [[panel URLs] firstObject];
        NSString *filename = [url lastPathComponent];
        static char fltBuf[256];
        strncpy(fltBuf, [filename UTF8String], sizeof(fltBuf) - 1);

        NSString *dir = [[url URLByDeletingLastPathComponent] lastPathComponent];
        bool isGru = [filename hasPrefix:@"gru"];

        g_result.flight_file = fltBuf;
        g_result.world_file = isGru ? "gru.wld" : "a.wld";
        g_result.ground_file = isGru ? "b.gru" : NULL;
        g_result.do_random = 0;
        g_result.no_crash = 0;
        g_result.demo = 0;
        g_result.want_sound = g_soundEnabled ? 1 : 0;
        g_result.quit = 0;
        g_pending = true;
    }
}

- (void)viewAction:(id)sender {
    sendKey((int)[sender tag]);
}

- (void)toggleSound:(id)sender {
    g_soundEnabled = !g_soundEnabled;
    [(NSMenuItem *)sender setTitle:g_soundEnabled ? @"Sound: ON" : @"Sound: OFF"];
    sound_set_master_volume(g_soundEnabled ? 50 : 0);
    [self updateVolumeTitle];
}

- (void)volumeUp:(id)sender {
    (void)sender;
    int vol = sound_get_master_volume();
    sound_set_master_volume(vol + 10);
    g_soundEnabled = sound_get_master_volume() > 0;
    [self updateVolumeTitle];
}

- (void)volumeDown:(id)sender {
    (void)sender;
    int vol = sound_get_master_volume();
    sound_set_master_volume(vol - 10);
    g_soundEnabled = sound_get_master_volume() > 0;
    [self updateVolumeTitle];
}

- (void)updateVolumeTitle {
    if (g_volumeItem)
        [g_volumeItem setTitle:[NSString stringWithFormat:@"Volume: %d%%", sound_get_master_volume()]];
}

- (void)showHelp:(id)sender {
    (void)sender;
    if (g_helpWindow && [g_helpWindow isVisible]) {
        [g_helpWindow makeKeyAndOrderFront:nil];
        return;
    }

    NSString *helpText =
        @"FLIGHT CONTROLS\n"
        "  *           100% throttle\n"
        "  /           0% throttle\n"
        "  + / -       Throttle up/down\n"
        "  I/M/J/L/K   Pitch/bank/center (keyboard yoke)\n"
        "  [ / ]       Rudder left/right\n"
        "  { / }       Center rudder\n"
        "  G           Landing gear\n"
        "  B           Speed brakes\n"
        "  W           Wheel brakes\n"
        "  F           Flaps toggle\n"
        "  . / ,       Flaps +5 / -5 degrees\n"
        "  ; / '       Trim up/down\n"
        "  A           Autopilot\n"
        "\n"
        "VIEWS\n"
        "  1           Front\n"
        "  2           Left\n"
        "  3           Right\n"
        "  4           Rear\n"
        "  5           Satellite\n"
        "  6           External\n"
        "  7           Track\n"
        "  8           Target track\n"
        "  9           Flyby\n"
        "  0           Virtual cockpit\n"
        "  &           Padlock view\n"
        "  z / \\       Front-left / Front-right\n"
        "  s/S/d/D     Rotate view right/left/down/up\n"
        "  U/u         External distance +/-\n"
        "\n"
        "WEAPONS\n"
        "  Space       Fire weapon\n"
        "  X           Arm/disarm weapon\n"
        "  N           Next weapon\n"
        "  Enter       Next target\n"
        "\n"
        "DISPLAY\n"
        "  C           Cockpit toggle\n"
        "  H           HUD toggle\n"
        "  Y           Airframe toggle\n"
        "  V           Velocity vector\n"
        "  %           Clouds toggle\n"
        "  ^           Textured terrain toggle\n"
        "  ?           Wireframe mode\n"
        "  >           Frame rate display\n"
        "\n"
        "GAME\n"
        "  P           Pause\n"
        "  Tab / ~     Next aircraft\n"
        "  (           Return to own plane\n"
        "  E           Screenshot (saves .ppm)\n"
        "  Q / Esc     Quit mission";

    NSRect frame = NSMakeRect(200, 200, 420, 600);
    g_helpWindow = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    [g_helpWindow setTitle:@"Sabre - Key Bindings"];
    [g_helpWindow setReleasedWhenClosed:NO];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:[[g_helpWindow contentView] bounds]];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    NSTextView *textView = [[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]];
    [textView setEditable:NO];
    [textView setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
    [textView setString:helpText];
    [textView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    [scrollView setDocumentView:textView];
    [g_helpWindow setContentView:scrollView];
    [g_helpWindow makeKeyAndOrderFront:nil];
}

- (void)quitAction:(id)sender {
    (void)sender;
    g_result.quit = 1;
    g_pending = true;
}

@end

static MenuDelegate *g_delegate = nil;

static void addItem(NSMenu *menu, NSString *title, SEL action, NSString *key, int tag, id target)
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    [item setTag:tag];
    [item setTarget:target];
    [menu addItem:item];
}

void setupMenu()
{
    g_pending = false;
    g_pendingKey = 0;
    g_result = {};
    g_result.flight_file = "furball.flt";
    g_result.world_file = "a.wld";
    g_result.want_sound = 1;

    g_delegate = [[MenuDelegate alloc] init];
    NSMenu *menuBar = [[NSMenu alloc] init];

    // App menu
    {
        NSMenuItem *mi = [[NSMenuItem alloc] init];
        NSMenu *m = [[NSMenu alloc] initWithTitle:@"Sabre"];
        addItem(m, @"About Sabre", nil, @"", 0, nil);
        [m addItem:[NSMenuItem separatorItem]];
        addItem(m, @"Quit Sabre", @selector(quitAction:), @"q", 0, g_delegate);
        [mi setSubmenu:m];
        [menuBar addItem:mi];
    }

    // Fly Mission menu
    {
        NSMenuItem *mi = [[NSMenuItem alloc] init];
        NSMenu *m = [[NSMenu alloc] initWithTitle:@"Fly Mission"];
        NSArray *names = @[
            @"Just Fly (no crash)", @"Takeoff from Runway",
            @"Target Practice 1", @"Target Practice 2", @"Target Practice 3",
            @"Dogfight - 1v1 MiG-15", @"Furball - Mass Air Combat",
            @"Melee - Five on Five", @"MiG Jump - Ride with Cdr Jing",
            @"Yak Attack - Mustang vs Yak", @"Thunder - F-84 vs MiG-15",
            @"Pistons - Prop Fighters",
            @"Ground Attack 1 - F-84", @"Ground Attack 2 - F-86", @"Ground Attack 3 - F-86",
        ];
        for (int i = 0; i < (int)[names count]; i++)
            addItem(m, names[i], @selector(missionAction:), @"", i, g_delegate);
        [m addItem:[NSMenuItem separatorItem]];
        addItem(m, @"Open Flight File...", @selector(customMission:), @"o", 0, g_delegate);
        [mi setSubmenu:m];
        [menuBar addItem:mi];
    }

    // Watch Demo menu
    {
        NSMenuItem *mi = [[NSMenuItem alloc] init];
        NSMenu *m = [[NSMenu alloc] initWithTitle:@"Watch Demo"];
        NSArray *names = @[
            @"Furball - Mass Air Combat", @"Melee - Five on Five",
            @"MiG Jump - Ride with Cdr Jing", @"Yak Attack - Mustang vs Yak",
            @"Thunder - F-84 vs MiG-15", @"Pistons - Prop Fighters",
        ];
        for (int i = 0; i < (int)[names count]; i++)
            addItem(m, names[i], @selector(demoAction:), @"", i, g_delegate);
        [mi setSubmenu:m];
        [menuBar addItem:mi];
    }

    // View menu
    {
        NSMenuItem *mi = [[NSMenuItem alloc] init];
        NSMenu *m = [[NSMenu alloc] initWithTitle:@"View"];

        addItem(m, @"Front",          @selector(viewAction:), @"1", FI_VIEW_FRONT, g_delegate);
        addItem(m, @"Left",           @selector(viewAction:), @"2", FI_VIEW_LEFT, g_delegate);
        addItem(m, @"Right",          @selector(viewAction:), @"3", FI_VIEW_RIGHT, g_delegate);
        addItem(m, @"Rear",           @selector(viewAction:), @"4", FI_VIEW_REAR, g_delegate);
        [m addItem:[NSMenuItem separatorItem]];
        addItem(m, @"Satellite",      @selector(viewAction:), @"5", FI_VIEW_SATELLITE, g_delegate);
        addItem(m, @"External",       @selector(viewAction:), @"6", FI_VIEW_EXTERNAL, g_delegate);
        addItem(m, @"Track",          @selector(viewAction:), @"7", FI_VIEW_TRACK, g_delegate);
        addItem(m, @"Target Track",   @selector(viewAction:), @"8", FI_VIEW_TARGET_TRACK, g_delegate);
        addItem(m, @"Flyby",          @selector(viewAction:), @"9", FI_VIEW_FLYBY, g_delegate);
        [m addItem:[NSMenuItem separatorItem]];
        addItem(m, @"Virtual Cockpit",@selector(viewAction:), @"0", FI_VIEW_VIRTUAL, g_delegate);
        addItem(m, @"Padlock",        @selector(viewAction:), @"",  FI_VIEW_PADLOCK, g_delegate);

        [mi setSubmenu:m];
        [menuBar addItem:mi];
    }

    // Settings menu
    {
        NSMenuItem *mi = [[NSMenuItem alloc] init];
        NSMenu *m = [[NSMenu alloc] initWithTitle:@"Settings"];
        addItem(m, @"Sound: ON", @selector(toggleSound:), @"", 0, g_delegate);
        [m addItem:[NSMenuItem separatorItem]];
        addItem(m, @"Volume Up", @selector(volumeUp:), @"+", 0, g_delegate);
        addItem(m, @"Volume Down", @selector(volumeDown:), @"-", 0, g_delegate);
        g_volumeItem = [[NSMenuItem alloc] initWithTitle:@"Volume: 50%" action:nil keyEquivalent:@""];
        [g_volumeItem setEnabled:NO];
        [m addItem:g_volumeItem];
        [mi setSubmenu:m];
        [menuBar addItem:mi];
    }

    // Help menu
    {
        NSMenuItem *mi = [[NSMenuItem alloc] init];
        NSMenu *m = [[NSMenu alloc] initWithTitle:@"Help"];
        addItem(m, @"Key Bindings", @selector(showHelp:), @"/", 0, g_delegate);
        [mi setSubmenu:m];
        [menuBar addItem:mi];
    }

    [NSApp setMainMenu:menuBar];
}

int menuPending()
{
    return g_pending ? 1 : 0;
}

MenuResult getMenuResult()
{
    g_pending = false;
    return g_result;
}

int menuKeyPending()
{
    return g_pendingKey != 0 ? 1 : 0;
}

int getMenuKey()
{
    int k = g_pendingKey;
    g_pendingKey = 0;
    return k;
}
