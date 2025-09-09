//
//  KJFileUtils.h
//  OCUnusedResourceChecking
//
//  Created by TigerHu on 2025/9/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KJFileUtils : NSObject

/**
 *  get file size, contain directory
 *  @param path  path
 *  @param isDir isDir
 *
 *  @return unsigned long long
 */
+ (uint64_t)fileSizeAtPath:(NSString *)path isDir:(BOOL *)isDir;

/**
 *  get folder size
 *  @param path  path
 *
 *  @return unsigned long long
 */
+ (uint64_t)folderSizeAtPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
