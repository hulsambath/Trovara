#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SwiftTryCatchTryBlock)(void);
typedef void (^SwiftTryCatchCatchBlock)(NSException * _Nullable exception);
typedef void (^SwiftTryCatchFinallyBlock)(void);

@interface SwiftTryCatch : NSObject

+ (void)try:(SwiftTryCatchTryBlock)tryBlock
      catch:(SwiftTryCatchCatchBlock)catchBlock
    finally:(SwiftTryCatchFinallyBlock)finallyBlock NS_SWIFT_NAME(try(_:catch:finally:));

@end

NS_ASSUME_NONNULL_END
