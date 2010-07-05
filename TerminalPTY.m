#import "TerminalPTY.h"
#import "TerminalWindow.h"
#import "TerminalWindow_Emulation.h"

#import <util.h>
#import <unistd.h>
#import <sys/ioctl.h>
#import <pwd.h>

@implementation TerminalPTY

- (id)initWithParent:(TerminalWindow *)tw winsize:(struct winsize)ws
{
    if(!(self = [super init])) return nil;

    parent = tw;
    alive = YES;
    
    // Need to get this BEFORE we fork, as CF isn't guaranteed to work afterwards
    const char *homedir = [NSHomeDirectory() fileSystemRepresentation];

    int term_fd;
    pid = forkpty(&term_fd, NULL, NULL, &ws);
    
    if(pid < 0) {
        NSLog(@"forkpty failed");
        [self release];
        return nil;
    } else if(pid == 0) {
        setsid();
        chdir(homedir);
        
        setenv("TERM", "vt100+", 1); // XXX: need to make this flexible
        
        struct passwd *pwd = getpwuid(getuid());
        char *shell = (pwd && pwd->pw_shell) ? pwd->pw_shell : "/bin/sh";
        endpwent();
        
        execl(shell, "-", NULL);
        printf("failed to exec shell %s: %s\n", shell, strerror(errno));
        exit(255);
    }

    term = [[NSFileHandle alloc] initWithFileDescriptor:term_fd closeOnDealloc:YES];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(gotData:)
        name:NSFileHandleDataAvailableNotification
        object:term];

    [term waitForDataInBackgroundAndNotifyForModes:
        [NSArray arrayWithObjects:NSDefaultRunLoopMode,
                                  NSModalPanelRunLoopMode,
                                  NSEventTrackingRunLoopMode, nil]];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [term release];
    [super dealloc];
}

- (void)setSize:(struct winsize)ws
{
    if(alive)
        ioctl([term fileDescriptor], TIOCSWINSZ, &ws);
}

- (void)writeData:(NSData *)dat
{
    if(alive)
        [term writeData:dat];
}

- (BOOL)alive
{
    return alive;
}

- (void)gotData:(NSNotification *)note
{
    NSData *buf = [term availableData];
    if([buf length] == 0) {
        alive = NO;
        [term closeFile];
        [parent ptyClosed:self];
        return;
    }

    [parent ptyInput:self data:buf];

    [term waitForDataInBackgroundAndNotifyForModes:
        [NSArray arrayWithObjects:NSDefaultRunLoopMode,
                                  NSModalPanelRunLoopMode,
                                  NSEventTrackingRunLoopMode, nil]];
}

@end

// vim: set syn=objc: