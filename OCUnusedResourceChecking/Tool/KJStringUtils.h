//
//  KJStringUtils.h
//  OCUnusedResourceChecking
//
//  Created by TigerHu on 2025/9/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KJStringUtils : NSObject

+ (NSString *)stringByRemoveResourceSuffix:(NSString *)str;
+ (NSString *)stringByRemoveResourceSuffix:(NSString *)str suffix:(NSString *)suffix;

+ (BOOL)isImageTypeWithName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
