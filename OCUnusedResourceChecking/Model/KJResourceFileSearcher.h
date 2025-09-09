//
//  KJResourceFileSearcher.h
//  OCUnusedResourceChecking
//
//  Created by TigerHu on 2025/9/8.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kNotificationResourceFileQueryDone;

@interface KJResourceFileInfo : NSObject

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *path;
@property (assign, nonatomic) BOOL isDir;
@property (assign, nonatomic) uint64_t fileSize;

- (NSImage *)image;

@end

@interface KJResourceFileSearcher : NSObject
/**< dict<NSString *name, ResourceFileInfo *info> */
@property (strong, nonatomic, readonly) NSMutableDictionary *resNameInfoDict;

+ (instancetype)sharedObject;

/// 资源文件搜索🔍
/// - Parameters:
///   - projectPath: 工程根目录
///   - excludeFolders: 忽略文件夹名，多个以｜分割
///   - resourceSuffixs: 资源后缀
- (void)startWithProjectPath:(NSString *)projectPath
              excludeFolders:(NSArray *)excludeFolders
             resourceSuffixs:(NSArray *)resourceSuffixs;

- (void)reset;

- (BOOL)isImageSetFolder:(NSString *)folder;

@end

NS_ASSUME_NONNULL_END
