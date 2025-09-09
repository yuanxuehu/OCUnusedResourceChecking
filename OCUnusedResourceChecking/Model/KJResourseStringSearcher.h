//
//  KJResourceStringSearcher.h
//  OCUnusedResourceChecking
//
//  Created by TigerHu on 2025/9/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kNotificationResourceStringQueryDone;

@interface KJResourceStringPattern : NSObject

@property (strong, nonatomic) NSString *suffix;
@property (assign, nonatomic) BOOL enable;
@property (strong, nonatomic) NSString *regex;
@property (assign, nonatomic) NSInteger groupIndex;

- (id)initWithDictionary:(NSDictionary *)dict;

@end


@interface KJResourceStringSearcher : NSObject
///正则表达式匹配出来的代码中有用到资源名，元素类型为NSString
@property (strong, nonatomic, readonly) NSMutableSet *resStringSet;

+ (instancetype)sharedObject;

/// 资源字符搜索🔍
/// - Parameters:
///   - projectPath: 工程根目录
///   - excludeFolders: 忽略文件夹名数组，多个以｜分割
///   - resourceSuffixs: 资源后缀数据
///   - resourcePatterns: 资源匹配规则数组
- (void)startWithProjectPath:(NSString *)projectPath
              excludeFolders:(NSArray *)excludeFolders
             resourceSuffixs:(NSArray *)resourceSuffixs
            resourcePatterns:(NSArray *)resourcePatterns;

- (void)reset;

- (BOOL)containsResourceName:(NSString *)name;

/**
 *  If resource name is: "icon_tag_1.png", and using in code by "icon_tag_%d", this resource is used with a similar name.
 *
 *  @param name resource name
 *
 *  @return BOOL
 */
- (BOOL)containsSimilarResourceName:(NSString *)name;

- (NSArray *)createDefaultResourcePatternsWithResourceSuffixs:(NSArray *)resSuffixs;

- (NSDictionary *)createEmptyResourcePattern;

@end

NS_ASSUME_NONNULL_END
