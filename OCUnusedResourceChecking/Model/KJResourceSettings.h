//
//  KJResourceSettings.h
//  OCUnusedResourceChecking
//
//  Created by TigerHu on 2025/9/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///未使用资源搜索配置类
@interface KJResourceSettings : NSObject

@property (strong, nonatomic) NSString *projectPath;
@property (strong, nonatomic) NSArray *excludeFolders; /**< <NSString *> */
@property (strong, nonatomic) NSArray *resourceSuffixs; /**< <NSString *> */
@property (strong, nonatomic) NSArray *resourcePatterns; /**< <NSDictionary *> */
@property (strong, nonatomic) NSNumber *matchSimilarName;

+ (instancetype)sharedObject;

- (void)updateResourcePatternAtIndex:(NSInteger)index withObject:(id)obj forKey:(NSString *)key;

- (void)addResourcePattern:(NSDictionary *)pattern;
- (void)removeResourcePatternAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
