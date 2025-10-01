#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const kOriginalIP = @"47.236.163.198";
static NSString *const kRedirectIP = @"45.192.97.150";
static NSString *const kClassName = @"AFHTTPSessionManager";
static NSString *const kPassword = @"111111";

static id (*original_requestMethod)(id self, SEL _cmd, ...) = NULL;

id hooked_requestMethod(id self, SEL _cmd, id request) {
    @autoreleasepool {
        if ([request isKindOfClass:NSClassFromString(@"NSURLRequest")]) {
            NSURL *originalURL = [request valueForKey:@"URL"];
            
            if (originalURL && [originalURL.host isEqualToString:kOriginalIP]) {
                NSURLComponents *components = [NSURLComponents componentsWithURL:originalURL resolvingAgainstBaseURL:NO];
                components.host = kRedirectIP;
                
                NSURL *newURL = components.URL;
                if (newURL) {
                    NSMutableURLRequest *newRequest = [request mutableCopy];
                    [newRequest setURL:newURL];
                    
                    NSLog(@"URL已被替换：%@ -> %@", originalURL, newURL);
                    
                    if (original_requestMethod) {
                        return original_requestMethod(self, _cmd, newRequest);
                    }
                }
            }
        }
        
        if (original_requestMethod) {
            return original_requestMethod(self, _cmd, request);
        }
        
        return nil;
    }
}

__attribute__((constructor))
static void installHook() {
    @autoreleasepool {
        Class targetClass = NSClassFromString(kClassName);
        
        if (!targetClass) {
            NSLog(@"未找到 AFHTTPSessionManager 类");
            return;
        }
        
        SEL targetSelector = @selector(dataTaskWithRequest:);
        Method targetMethod = class_getInstanceMethod(targetClass, targetSelector);
        
        if (!targetMethod) {
            targetSelector = @selector(POST:parameters:progress:success:failure:);
            targetMethod = class_getInstanceMethod(targetClass, targetSelector);
        }
        
        if (targetMethod) {
            original_requestMethod = (id (*)(id, SEL, ...))method_getImplementation(targetMethod);
            method_setImplementation(targetMethod, (IMP)hooked_requestMethod);
            NSLog(@"Method hook 成功");
        } else {
            NSLog(@"获取方法失败");
        }
    }
}
