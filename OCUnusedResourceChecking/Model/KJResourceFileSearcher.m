//
//  KJResourceFileSearcher.m
//  OCUnusedResourceChecking
//
//  Created by TigerHu on 2025/9/8.
//

#import "KJResourceFileSearcher.h"
#import "KJStringUtils.h"
#import "KJFileUtils.h"

NSString * const kNotificationResourceFileQueryDone = @"kNotificationResourceFileQueryDone";

static NSString * const kSuffixImageSet    = @".imageset";
static NSString * const kSuffixLaunchImage = @".launchimage";
static NSString * const kSuffixAppIcon     = @".appiconset";
static NSString * const kSuffixBundle      = @".bundle";
static NSString * const kSuffixPng         = @".png";


@implementation KJResourceFileInfo

- (NSImage *)image {
    
    if ([KJStringUtils isImageTypeWithName:self.name]) {
        return [[NSImage alloc] initByReferencingFile:self.path];
    }
    
    if ([[KJResourceFileSearcher sharedObject] isImageSetFolder:self.name]) {
        NSError *error = nil;
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:&error];
        if (files.count == 0) {
            return nil;
        }
        
        for (NSString *file in files) {
            if ([KJStringUtils isImageTypeWithName:file]) {
                return [[NSImage alloc] initByReferencingFile:[self.path stringByAppendingPathComponent:file]];
            }
        }
    }
    
    return nil;
}

@end


@interface KJResourceFileSearcher ()

@property (assign, nonatomic) BOOL isRunning;
///找出文件中所有的资源名（集合：key为资源名，value为KJResourceFileInfo)
@property (strong, nonatomic) NSMutableDictionary *resNameInfoDict;
@end


@implementation KJResourceFileSearcher

+ (instancetype)sharedObject {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}


/// 资源文件搜索🔍
/// - Parameters:
///   - projectPath: 工程根目录
///   - excludeFolders: 忽略文件夹名，多个以｜分割
///   - resourceSuffixs: 资源后缀
- (void)startWithProjectPath:(NSString *)projectPath
              excludeFolders:(NSArray *)excludeFolders
             resourceSuffixs:(NSArray *)resourceSuffixs {
    
    if (self.isRunning) {
        return;
    }
    if (projectPath.length == 0 || resourceSuffixs.count == 0) {
        return;
    }
    
    self.isRunning = YES;
    
    [self scanResourceFileWithProjectPath:projectPath
                           excludeFolders:excludeFolders
                          resourceSuffixs:resourceSuffixs];
}

- (void)reset {
    
    self.isRunning = NO;
    [self.resNameInfoDict removeAllObjects];
}

- (BOOL)isImageSetFolder:(NSString *)folder
{
    
    if ([folder hasSuffix:kSuffixImageSet]
        || [folder hasSuffix:kSuffixAppIcon]
        || [folder hasSuffix:kSuffixLaunchImage]) {
        return YES;
    }
    return NO;
}

- (BOOL)isInImageSetFolder:(NSString *)folder
{
    
    if (![self isImageSetFolder:folder]
        && ([folder rangeOfString:kSuffixImageSet].location != NSNotFound
        || [folder rangeOfString:kSuffixAppIcon].location != NSNotFound
        || [folder rangeOfString:kSuffixLaunchImage].location != NSNotFound)) {
        return YES;
    }
    return NO;
}

#pragma mark - Private

- (void)scanResourceFileWithProjectPath:(NSString *)projectPath
                         excludeFolders:(NSArray *)excludeFolders
                        resourceSuffixs:(NSArray *)resourceSuffixs {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
       
        NSArray *resPaths = [self resourceFilesInDirectory:projectPath
                                            excludeFolders:excludeFolders
                                           resourceSuffixs:resourceSuffixs];
        
        NSMutableDictionary *tempResNameInfoDict = [NSMutableDictionary dictionary];
        for (NSString *path in resPaths) {
            NSString *name = [path lastPathComponent];
            if (!name.length) {
                continue;
            }
            
            NSString *keyName = [KJStringUtils stringByRemoveResourceSuffix:name];

            if (!tempResNameInfoDict[keyName]) {
                BOOL isDir = NO;
                KJResourceFileInfo *info = [KJResourceFileInfo new];
                info.name = name;
                info.path = path;
                info.fileSize = [KJFileUtils fileSizeAtPath:path isDir:&isDir];
                info.isDir = isDir;
                tempResNameInfoDict[keyName] = info;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.resNameInfoDict = tempResNameInfoDict;
            self.isRunning = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationResourceFileQueryDone object:nil userInfo:nil];
        });
    });
}

- (NSArray *)resourceFilesInDirectory:(NSString *)directoryPath
                       excludeFolders:(NSArray *)excludeFolders
                      resourceSuffixs:(NSArray *)suffixs {
    
    NSMutableArray *resources = [NSMutableArray array];
    
    for (NSString *fileType in suffixs) {
        // list of path<NSString>
        NSArray *pathList = [self searchDirectory:directoryPath
                                   excludeFolders:excludeFolders
                                      forFiletype:fileType];
        if (pathList.count) {
            for (NSString *path in pathList) {
                // ignore if the resource file is in xxx/xxx.imageset/; xx/LaunchImage.launchimage; xx/AppIcon.appiconset; xx.bundle/xx
                if (![self isInImageSetFolder:path]
                    && [path rangeOfString:kSuffixBundle].location == NSNotFound) {
                    [resources addObject:path];
                }
            }
        }
    }
    
    return resources;
}

///所有符合筛选条件的文件夹数组
- (NSArray *)searchDirectory:(NSString *)directoryPath
              excludeFolders:(NSArray *)excludeFolders
                 forFiletype:(NSString *)filetype {
    
    // Create a find task
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/find"];
    
    // Search for all files
    NSMutableArray *argvals = [NSMutableArray array];
    [argvals addObject:directoryPath];
    [argvals addObject:@"-name"];
    [argvals addObject:[NSString stringWithFormat:@"*.%@", filetype]];
    
    // 指定的忽略文件夹路径
    for (NSString *folder in excludeFolders) {
        [argvals addObject:@"!"];
        [argvals addObject:@"-path"];
        [argvals addObject:[NSString stringWithFormat:@"*/%@/*", folder]];
    }
    
    [task setArguments:argvals];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    // Run task
    [task launch];
    
    // Read the response
    NSData *data = [file readDataToEndOfFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    // See if we can create a lines array
    if (string.length) {
        NSArray *lines = [string componentsSeparatedByString:@"\n"];
        return lines;
    }
    
    return nil;
}


// Toooooo Sloooooow 效率太低（废弃方案）
- (NSArray *)searchDirectory:(NSString *)directoryPath
              excludeFolders:(NSArray *)excludeFolders
                forFiletypes:(NSArray *)filetypes {
    
    // find -E . -iregex ".*\.(html|plist)" ! -path "*/Movies/*" ! -path "*/Downloads/*" ! -path "*/Music/*"
    // Create a find task
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/bin/find"];
    
    // Search for all files
    NSMutableArray *argvals = [NSMutableArray array];
    [argvals addObject:@"-E"];
    [argvals addObject:directoryPath];
    [argvals addObject:@"-iregex"];
    
    [argvals addObject:[NSString stringWithFormat:@".*\\.(%@)", [filetypes componentsJoinedByString:@"|"]]];
    
    for (NSString *folder in excludeFolders) {
        [argvals addObject:@"!"];
        [argvals addObject:@"-path"];
        [argvals addObject:[NSString stringWithFormat:@"*/%@/*", folder]];
    }
    
    [task setArguments: argvals];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    // Run task
    [task launch];
    
    // Read the response
    NSData *data = [file readDataToEndOfFile];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    // See if we can create a lines array
    if (string.length) {
        NSArray *lines = [string componentsSeparatedByString:@"\n"];
        return lines;
    }
    
    return nil;
}
                                                             
@end
