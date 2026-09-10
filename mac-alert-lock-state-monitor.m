// Persistent per-user monitor for the locked-only mode. It receives macOS GUI
// session notifications and writes a tiny private state file for the watcher.
#import <Foundation/Foundation.h>
#include <sys/stat.h>

static NSString *statePath;

static void writeState(NSString *state) {
  NSString *contents = [state stringByAppendingString:@"\n"];
  if ([contents writeToFile:statePath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
    chmod(statePath.fileSystemRepresentation, S_IRUSR | S_IWUSR);
  }
}

@interface LockStateObserver : NSObject
@end

@implementation LockStateObserver
- (void)screenLocked:(NSNotification *)notification { writeState(@"locked"); }
- (void)screenUnlocked:(NSNotification *)notification { writeState(@"unlocked"); }
@end

int main(int argc, const char * argv[]) {
  @autoreleasepool {
    if (argc != 2) return 64;
    statePath = [NSString stringWithUTF8String:argv[1]];
    // Fail closed: locked-only alerts wait for an observed lock event.
    writeState(@"unknown");
    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    LockStateObserver *observer = [[LockStateObserver alloc] init];
    [center addObserver:observer selector:@selector(screenLocked:)
                    name:@"com.apple.screenIsLocked" object:nil
      suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    [center addObserver:observer selector:@selector(screenUnlocked:)
                    name:@"com.apple.screenIsUnlocked" object:nil
      suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
