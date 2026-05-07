#import "SwiftTryCatch.h"

@implementation SwiftTryCatch

+ (void)try:(SwiftTryCatchTryBlock)tryBlock
      catch:(SwiftTryCatchCatchBlock)catchBlock
    finally:(SwiftTryCatchFinallyBlock)finallyBlock {
  @try {
    if (tryBlock) {
      tryBlock();
    }
  } @catch (NSException *exception) {
    if (catchBlock) {
      catchBlock(exception);
    }
  } @finally {
    if (finallyBlock) {
      finallyBlock();
    }
  }
}

@end
