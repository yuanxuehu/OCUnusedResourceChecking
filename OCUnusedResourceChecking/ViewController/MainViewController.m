//
//  MainViewController.m
//  OCUnusedResourceChecking
//
//  Created by TigerHu on 2025/9/8.
//


#import "MainViewController.h"
#import "KJResourceFileSearcher.h"
#import "KJResourseStringSearcher.h"
#import "KJStringUtils.h"
#import "KJResourceSettings.h"

// Constant strings
static NSString * const kDefaultResourceSuffixs    = @"imageset|jpg|gif|png";
static NSString * const kDefaultResourceSeparator  = @"|";

static NSString * const kResultIdentifyFileIcon    = @"FileIcon";
static NSString * const kResultIdentifyFileName    = @"FileName";
static NSString * const kResultIdentifyFileSize    = @"FileSize";
static NSString * const kResultIdentifyFilePath    = @"FilePath";

@interface MainViewController ()
<NSTableViewDelegate,
NSTableViewDataSource,
NSTextFieldDelegate>

// Project
@property (weak) IBOutlet NSButton *browseButton;
@property (weak) IBOutlet NSTextField *pathTextField;
@property (weak) IBOutlet NSTextField *excludeFolderTextField;

// Settings
@property (weak) IBOutlet NSTextField *resSuffixTextField;

@property (weak) IBOutlet NSTableView *patternTableView;

@property (weak) IBOutlet NSButton *ignoreSimilarCheckbox;

// Result
@property (weak) IBOutlet NSTableView *resultsTableView;
@property (weak) IBOutlet NSProgressIndicator *processIndicator;
@property (weak) IBOutlet NSTextField *statusLabel;

@property (weak) IBOutlet NSButton *searchButton;
@property (weak) IBOutlet NSButton *exportButton;
@property (weak) IBOutlet NSButton *deleteButton;

@property (strong, nonatomic) NSMutableArray *unusedResults;
///资源文件检索完成
@property (assign, nonatomic) BOOL isFileDone;
///资源字符串检索完成
@property (assign, nonatomic) BOOL isStringDone;
@property (strong, nonatomic) NSDate *startTime;
@property (assign, nonatomic) BOOL isSortDescByFileSize;

@end

@implementation MainViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    [self setupSettings];
    
    // Setup tableview click action
    [self.resultsTableView setAction:@selector(onResultsTableViewSingleClicked)];
    [self.resultsTableView setDoubleAction:@selector(onResultsTableViewDoubleClicked)];
    
    self.resultsTableView.allowsEmptySelection = YES;
    self.resultsTableView.allowsMultipleSelection = YES;
    self.patternTableView.allowsEmptySelection = YES;
    self.patternTableView.allowsMultipleSelection = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onResourceFileQueryDone:) name:kNotificationResourceFileQueryDone object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onResourceStringQueryDone:) name:kNotificationResourceStringQueryDone object:nil];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark - Action

- (IBAction)onBrowseButtonClicked:(id)sender {
    
    // Show an open panel 仅可以选中文件夹
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    
    BOOL okButtonPressed = ([openPanel runModal] == NSModalResponseOK);
    if (okButtonPressed) {
        // Update the path text field
        NSString *path = [[openPanel URL] path];
        [KJResourceSettings sharedObject].projectPath = path;
        [self.pathTextField setStringValue:path];
    }
}

- (IBAction)onSearchButtonClicked:(id)sender {
    
    // Check if user has selected or entered a path
    NSString *projectPath = self.pathTextField.stringValue;
    if (!projectPath.length) {
        [self showAlertWithStyle:NSAlertStyleWarning title:@"Path Error" subtitle:@"Project path is empty"];
        return;
    }
    
    // Check the path exists
    BOOL pathExists = [[NSFileManager defaultManager] fileExistsAtPath:projectPath];
    if (!pathExists) {
        [self showAlertWithStyle:NSAlertStyleWarning title:@"Path Error" subtitle:@"Project folder is not exists"];
        return;
    }
    
    self.startTime = [NSDate date];
    
    // Reset 检测前重置标识数据
    [[KJResourceFileSearcher sharedObject] reset];
    [[KJResourceStringSearcher sharedObject] reset];
    
    [self.unusedResults removeAllObjects];
    [self.resultsTableView reloadData];
    
    self.isFileDone = NO;
    self.isStringDone = NO;
    
    NSArray *resourceSuffixs = [self resourceSuffixs];
    if (!resourceSuffixs.count) {
        [self showAlertWithStyle:NSAlertStyleWarning title:@"Suffix Error" subtitle:@"Resource suffix is invalid"];
        return;
    }

    NSArray *excludeFolders = [KJResourceSettings sharedObject].excludeFolders;
    
    //开始启动检测
    [[KJResourceFileSearcher sharedObject] startWithProjectPath:projectPath
                                                 excludeFolders:excludeFolders
                                                resourceSuffixs:resourceSuffixs];
    
    [[KJResourceStringSearcher sharedObject] startWithProjectPath:projectPath
                                                   excludeFolders:excludeFolders
                                                  resourceSuffixs:resourceSuffixs
                                                 resourcePatterns:[self resourcePatterns]];
    
    ///检测中置灰按钮
    [self setUIEnabled:NO];
}

///导出数据
- (IBAction)onExportButtonClicked:(id)sender {
    
    NSSavePanel *save = [NSSavePanel savePanel];
    [save setAllowedFileTypes:[NSArray arrayWithObject:@"txt"]];
    
    BOOL okButtonPressed = ([save runModal] == NSModalResponseOK);
    if (okButtonPressed) {
        NSString *selectedFile = [[save URL] path];
        
        NSMutableString *outputResults = [[NSMutableString alloc] init];
        NSString *projectPath = [self.pathTextField stringValue];
        [outputResults appendFormat:@"Unused Resources In Project: \n%@\n\n", projectPath];
        
        for (KJResourceFileInfo *info in self.unusedResults) {
            [outputResults appendFormat:@"%@\n", info.path];
        }
        
        // Output
        NSError *writeError = nil;
        [outputResults writeToFile:selectedFile atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
        
        // Check write result
        if (writeError == nil) {
            [self showAlertWithStyle:NSAlertStyleInformational title:@"Export Complete" subtitle:[NSString stringWithFormat:@"Export Complete: %@", selectedFile]];
        } else {
            [self showAlertWithStyle:NSAlertStyleCritical title:@"Export Error" subtitle:[NSString stringWithFormat:@"Export Error: %@", writeError]];
        }
    }
}

///清除检测数据
- (IBAction)onDeleteButtonClicked:(id)sender {
    
    if (self.resultsTableView.numberOfSelectedRows > 0) {
        NSArray *results = [self.unusedResults copy];
        NSIndexSet *selectedIndexSet = self.resultsTableView.selectedRowIndexes;
        NSUInteger index = [selectedIndexSet firstIndex];
        while (index != NSNotFound) {
            if (index < results.count) {
                KJResourceFileInfo *info = [results objectAtIndex:index];
                [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:info.path] error:nil];
            }
            index = [selectedIndexSet indexGreaterThanIndex:index];
        }
        
        [self.unusedResults removeObjectsAtIndexes:selectedIndexSet];
        [self.resultsTableView reloadData];
        [self updateUnusedResultsCount];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Please select any table column."];
        [alert runModal];
    }
}

///删除匹配正则表达式
- (IBAction)onRemovePatternButtonClicked:(id)sender {
    
    if (self.patternTableView.numberOfSelectedRows > 0) {
        NSIndexSet *selectedIndexSet = self.patternTableView.selectedRowIndexes;
        NSUInteger index = [selectedIndexSet firstIndex];
        [[KJResourceSettings sharedObject] removeResourcePatternAtIndex:index];
        [self.patternTableView reloadData];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Please select any table column."];
        [alert runModal];
    }
}

///新增匹配正则表达式
- (IBAction)onAddPatternButtonClicked:(id)sender {
    
    [[KJResourceSettings sharedObject] addResourcePattern:[[KJResourceStringSearcher sharedObject] createEmptyResourcePattern]];
    [self.patternTableView reloadData];
}

///单击鼠标复制资源名字
- (void)onResultsTableViewSingleClicked {
    
    // Copy to pasteboard
    NSInteger index = [self.resultsTableView clickedRow];
    if (self.unusedResults.count == 0 || index >= self.unusedResults.count) {
        return;
    }

    KJResourceFileInfo *info = [self.unusedResults objectAtIndex:index];
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:info.name forType:NSPasteboardTypeString];
}

///双击鼠标在Finder打开
- (void)onResultsTableViewDoubleClicked {
    
    // Open finder
    NSInteger index = [self.resultsTableView clickedRow];
    if (self.unusedResults.count == 0 || index >= self.unusedResults.count) {
        return;
    }
    
    KJResourceFileInfo *info = [self.unusedResults objectAtIndex:index];
    [[NSWorkspace sharedWorkspace] selectFile:info.path inFileViewerRootedAtPath:@""];
}

///☑️是否忽略类似的字符
///Ignore similar name (eg: tag_1.png, using with "tag_%d" or "tag" will be considered to be used )
- (IBAction)onIgnoreSimilarCheckboxClicked:(NSButton *)sender {
    [KJResourceSettings sharedObject].matchSimilarName = sender.state == NSControlStateValueOn ? @(YES) : @(NO);
}

#pragma mark - NSNotification

- (void)onResourceFileQueryDone:(NSNotification *)notification {
    
    self.isFileDone = YES;
    [self searchUnusedResourcesIfNeeded];
}

- (void)onResourceStringQueryDone:(NSNotification *)notification {
    
    self.isStringDone = YES;
    [self searchUnusedResourcesIfNeeded];
}

#pragma mark - <NSTableViewDataSource>

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    
    if (tableView == self.resultsTableView) {
        return self.unusedResults.count;
    } else {
        return [self resourcePatterns].count;
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    // Check the column
    NSString *identifier = [tableColumn identifier];
    if (tableView == self.resultsTableView) {
        // Get the unused image
        KJResourceFileInfo *info = [self.unusedResults objectAtIndex:row];
        
        if ([identifier isEqualToString:kResultIdentifyFileIcon]) {
            return [info image];
        } else if ([identifier isEqualToString:kResultIdentifyFileName]) {
            return info.name;
        } else if ([identifier isEqualToString:kResultIdentifyFileSize]) {
            return [NSString stringWithFormat:@"%.2f", info.fileSize / 1024.0];
        }
        
        return info.path;
    } else {
        NSDictionary *dict = [[self resourcePatterns] objectAtIndex:row];
        return dict[identifier];
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    if (tableView == self.patternTableView) {
        NSString *identifier = [tableColumn identifier];
        [[KJResourceSettings sharedObject] updateResourcePatternAtIndex:row withObject:object forKey:identifier];
        
        [tableView reloadData];
    }
}

#pragma mark - <NSTableViewDelegate>

- (void)tableView:(NSTableView *)tableView mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn {
    
    if (tableView == self.patternTableView) {
        return;
    }
    
    NSArray *array = nil;
    if ([tableColumn.identifier isEqualToString:kResultIdentifyFileSize]) {
        self.isSortDescByFileSize = !self.isSortDescByFileSize;
        
        if (self.isSortDescByFileSize) {
            array = [self.unusedResults sortedArrayUsingComparator:^NSComparisonResult(KJResourceFileInfo *obj1, KJResourceFileInfo *obj2) {
                return obj1.fileSize < obj2.fileSize;
            }];
        } else {
            array = [self.unusedResults sortedArrayUsingComparator:^NSComparisonResult(KJResourceFileInfo *obj1, KJResourceFileInfo *obj2) {
                return obj1.fileSize > obj2.fileSize;
            }];
        }
    } else if ([tableColumn.identifier isEqualToString:kResultIdentifyFileName]) {
        array = [self.unusedResults sortedArrayUsingComparator:^NSComparisonResult(KJResourceFileInfo *obj1, KJResourceFileInfo *obj2) {
            return [obj1.name compare:obj2.name];
        }];
    } else  if ([tableColumn.identifier isEqualToString:kResultIdentifyFilePath]){
        array = [self.unusedResults sortedArrayUsingComparator:^NSComparisonResult(KJResourceFileInfo *obj1, KJResourceFileInfo *obj2) {
            return [obj1.path compare:obj2.path];
        }];
    }
    
    if (array) {
        self.unusedResults = [array mutableCopy];
        [self.resultsTableView reloadData];
    }
}

#pragma mark - <NSTextFieldDelegate>

- (void)controlTextDidChange:(NSNotification *)notification {
    
    NSTextField *textField = [notification object];
    if (textField == self.pathTextField) {
        [KJResourceSettings sharedObject].projectPath = [textField stringValue];
    } else if (textField == self.excludeFolderTextField) {
        [KJResourceSettings sharedObject].excludeFolders = [[textField stringValue] componentsSeparatedByString:kDefaultResourceSeparator];
    } else if (textField == self.resSuffixTextField) {
        NSString *suffixs = [[textField stringValue] lowercaseString];
        suffixs = [suffixs stringByReplacingOccurrencesOfString:@" " withString:@""];
        suffixs = [suffixs stringByReplacingOccurrencesOfString:@"." withString:@""];
        [KJResourceSettings sharedObject].resourceSuffixs = [suffixs componentsSeparatedByString:kDefaultResourceSeparator];
    }
}

#pragma mark - Private
///提示弹框
- (void)showAlertWithStyle:(NSAlertStyle)style title:(NSString *)title subtitle:(NSString *)subtitle {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = style;
    [alert setMessageText:title];
    [alert setInformativeText:subtitle];
    [alert runModal];
}

- (NSArray *)resourceSuffixs {
    return [KJResourceSettings sharedObject].resourceSuffixs;
}

- (NSArray *)resourcePatterns {
    return [KJResourceSettings sharedObject].resourcePatterns;
}

- (void)setUIEnabled:(BOOL)state {
    
    if (state) {
        [self updateUnusedResultsCount];
    } else {
        [self.processIndicator startAnimation:self];
        self.statusLabel.stringValue = @"Searching...";
    }
    
    [_browseButton setEnabled:state];
    [_resSuffixTextField setEnabled:state];
    [_pathTextField setEnabled:state];
    [_excludeFolderTextField setEnabled:state];
    
    [_ignoreSimilarCheckbox setEnabled:state];

    [_searchButton setEnabled:state];
    [_exportButton setHidden:!state];
    [_deleteButton setEnabled:state];
    [_deleteButton setHidden:!state];
    [_processIndicator setHidden:state];
}

- (void)updateUnusedResultsCount {
    
    [self.processIndicator stopAnimation:self];
    NSUInteger count = self.unusedResults.count;
    NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:self.startTime];
    NSUInteger totalSize = 0;
    for(KJResourceFileInfo *info in self.unusedResults){
        totalSize += info.fileSize;
    }
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Total: %ld, unsued: %ld, time: %.2fs, size: %.2f KB", [[KJResourceFileSearcher sharedObject].resNameInfoDict allKeys].count, (long)count, time, (long)totalSize / 1024.0];
}

- (void)searchUnusedResourcesIfNeeded {
    
    NSString *tips = @"Searching...";
    if (self.isFileDone) {
        tips = [tips stringByAppendingString:[NSString stringWithFormat:@"%ld resources", [[KJResourceFileSearcher sharedObject].resNameInfoDict allKeys].count]];
    }
    if (self.isStringDone) {
        tips = [tips stringByAppendingString:[NSString stringWithFormat:@"%ld strings", [KJResourceStringSearcher sharedObject].resStringSet.count]];
    }
    self.statusLabel.stringValue = tips;
    
    if (self.isFileDone && self.isStringDone) {
        /// 两个条件缺一不可
        
#pragma mark - 核心关键代码
        NSArray *resNames = [[[KJResourceFileSearcher sharedObject].resNameInfoDict allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        // localizedCaseInsensitiveCompare表示进行不区分大小写的字符串比较
        if (resNames.count) {
            for (NSString *name in resNames) {
                if (![[KJResourceStringSearcher sharedObject] containsResourceName:name]) {
                    if (!self.ignoreSimilarCheckbox.state
                        || ![[KJResourceStringSearcher sharedObject] containsSimilarResourceName:name]) {
                        //TODO: if imageset name is A but contains png with name B, and using as B, should ignore A.imageset
                        
                        KJResourceFileInfo *resInfo = [KJResourceFileSearcher sharedObject].resNameInfoDict[name];
                        if (!resInfo.isDir
                            || ![self usingResWithDiffrentDirName:resInfo]) {
                            [self.unusedResults addObject:resInfo];
                        }
                    }
                }
            }
        }
    
        [self.resultsTableView reloadData];
        
        [self setUIEnabled:YES];
    }
}

- (BOOL)usingResWithDiffrentDirName:(KJResourceFileInfo *)resInfo {
    
    if (!resInfo.isDir) {
        return NO;
    }
    
    NSDirectoryEnumerator *fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:resInfo.path];
    for (NSString *fileName in fileEnumerator) {
        if (![KJStringUtils isImageTypeWithName:fileName]) {
            continue;
        }
        
        NSString *fileNameWithoutExt = [KJStringUtils stringByRemoveResourceSuffix:fileName];
        
        if ([fileNameWithoutExt isEqualToString:resInfo.name]) {
            return NO;
        }
        
        if ([[KJResourceStringSearcher sharedObject] containsResourceName:fileNameWithoutExt]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)setupSettings {
    
    self.unusedResults = [NSMutableArray array];
    
    [self.pathTextField setStringValue:[KJResourceSettings sharedObject].projectPath ? : @""];
    NSString *exclude = @"";
    if ([KJResourceSettings sharedObject].excludeFolders.count) {
        exclude = [[KJResourceSettings sharedObject].excludeFolders componentsJoinedByString:kDefaultResourceSeparator];
    }
    [self.excludeFolderTextField setStringValue:exclude];
    
    NSArray *resSuffixs = [KJResourceSettings sharedObject].resourceSuffixs;
    if (!resSuffixs.count) {
        ///竖线分割
        resSuffixs = [kDefaultResourceSuffixs componentsSeparatedByString:kDefaultResourceSeparator];
        [KJResourceSettings sharedObject].resourceSuffixs = resSuffixs;
    }
    [self.resSuffixTextField setStringValue:[resSuffixs componentsJoinedByString:kDefaultResourceSeparator]];
    
    NSArray *resPatterns = [self resourcePatterns];
//    if (!resPatterns.count) {
        resPatterns = [[KJResourceStringSearcher sharedObject] createDefaultResourcePatternsWithResourceSuffixs:resSuffixs];
        [KJResourceSettings sharedObject].resourcePatterns = resPatterns;
//    }
    
    NSNumber *matchSimilar = [KJResourceSettings sharedObject].matchSimilarName;
    [self.ignoreSimilarCheckbox setState:matchSimilar.boolValue ? NSControlStateValueOn : NSControlStateValueOff];
}

@end
