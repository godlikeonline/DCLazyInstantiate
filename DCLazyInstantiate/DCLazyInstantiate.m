//
//  DCLazyInstantiate.m
//  DCLazyInstantiate
//
//  Created by Youwei Teng on 7/15/15.
//  Copyright (c) 2015 dcard. All rights reserved.
//

#import "DCLazyInstantiate.h"
#import "DCLazyInstantiateConfig.h"
#import "DCSettingsWindowController.h"

@interface DCLazyInstantiate ()

@property (nonatomic, strong, readwrite) NSBundle *bundle;
@property (nonatomic, strong) DCSettingsWindowController *settingWindow;

@end

@implementation DCLazyInstantiate

DEF_SINGLETON(DCLazyInstantiate);

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
          sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin {
    if (self = [super init]) {
        // reference to plugin's bundle, for resource access
        self.bundle = plugin;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didApplicationFinishLaunchingNotification:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
    }
    return self;
}

- (void)didApplicationFinishLaunchingNotification:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidFinishLaunchingNotification object:nil];
    [DCLazyInstantiateConfig setupMenu];
}

- (void)generateLazyInstantiate:(id)sender {
    DVTSourceTextView *sourceTextView = [DCXcodeUtils currentSourceTextView];
	
    //Get the cursor line range
    NSString *viewContent = [sourceTextView string];
    NSRange lineRange = [viewContent lineRangeForRange:[sourceTextView selectedRange]];
    
//    NSRange lineRange = [viewContent lineRangeForRange:NSMakeRange([sourceTextView selectedRange].location, )];

    // Get the selected text using the range from above.
    NSString *selectedString = [sourceTextView.textStorage.string substringWithRange:lineRange];
    NSMutableDictionary* resultDic=[self makeClassAndVar:selectedString];
    NSString *lazyInstantiation = [self lazyInstantiationWithSelectedString:resultDic];
    
    //获取要addSubviews的代码
    NSString *subViewsCode=[self lazySubviewsCode:resultDic];
    
    //获取addSubviews代码添加的位置
    NSInteger *subViewsCodeLocation;
    
    //获取要添加约束的代码
    NSString *constraintCode = [self lazyConstraintsCode:resultDic];
    
    //获取约束代码添加的位置
    NSInteger *constraintCodeLocation;

    if (lazyInstantiation != nil && lazyInstantiation.length > 0) {
        [[DCXcodeUtils currentTextStorage] beginEditing];
        [[DCXcodeUtils currentTextStorage] replaceCharactersInRange:NSMakeRange((sourceTextView.string.length - 5), 0) withString:subViewsCode withUndoManager:[[DCXcodeUtils currentSourceCodeDocument] undoManager]];
        [[DCXcodeUtils currentTextStorage] replaceCharactersInRange:NSMakeRange((sourceTextView.string.length - 5), 0) withString:constraintCode withUndoManager:[[DCXcodeUtils currentSourceCodeDocument] undoManager]];
        [[DCXcodeUtils currentTextStorage] replaceCharactersInRange:NSMakeRange((sourceTextView.string.length - 5), 0) withString:lazyInstantiation withUndoManager:[[DCXcodeUtils currentSourceCodeDocument] undoManager]];
        [[DCXcodeUtils currentTextStorage] endEditing];
    }
}

//生成addSubviews的代码
-(NSString*)lazySubviewsCode:(NSMutableDictionary *)dic {
    //先判断有没有子方法
    
    __block NSString *string =@"-(void)initUI {\n";
    if (dic) {
        [dic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *str=[NSString stringWithFormat:@"\t[self.view addSubview:self.%@];\n",key];
            string = [NSString stringWithFormat:@"%@%@",string,str];
        }];
        string = [NSString stringWithFormat:@"%@}\n\n",string];
        return string;
    }else {
        return nil;
    }
}

//生成约束代码
-(NSString*)lazyConstraintsCode:(NSMutableDictionary *)dic {
    //先判断有没有子方法
    
    __block NSString *string =@"-(void)initUIConstraints {\n";
    if (dic) {
        [dic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *str=[NSString stringWithFormat:@"\t[self.%@ mas_makeConstraints:^(MASConstraintMaker *make) {\n\tmake.left.equalTo().with.offset(0);\n\tmake.right.equalTo().with.offset(0);\n\tmake.bottom.equalTo().with.offset(0);\n\tmake.height.mas_equalTo().with.offset(0);\n\tmake.width.mas_equalTo().with.offset(0);\n\t}];\n\n",key];
            string = [NSString stringWithFormat:@"%@%@",string,str];
        }];
        string = [NSString stringWithFormat:@"%@}\n\n",string];
        return string;
    }else {
        return nil;
    }
}

//生成属性代码
- (NSString *)lazyInstantiationWithSelectedString:(NSMutableDictionary *)dic {
    __block NSString *string=@"";
    if (dic) {
//        [dic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
//            string = [NSString stringWithFormat:@"%@%@",[self InstantiateString:key VarName:obj],string];
//        }];
        for (NSString* key in dic.allKeys) {
            string = [NSString stringWithFormat:@"%@%@",[self InstantiateString:dic[key] VarName:key],string];
        }
    }
    
    return string;
}

- (void)showSetting:(id)sender {
    if (nil == self.settingWindow) {
        self.settingWindow = [[DCSettingsWindowController alloc] initWithWindowNibName:NSStringFromClass([DCSettingsWindowController class])];
    }
    [self.settingWindow showWindow:self.settingWindow];
}

//
-(NSString*)InstantiateString:(NSString*)class VarName:(NSString*)varName {
    if ([class isEqual:@"UIButton"]) {
        return [NSString stringWithFormat:@"- (%@ *)%@ {\n\tif (!_%@) {\n\t_%@ = ({\n            UIButton *button = [[UIButton alloc] init];\n            button.backgroundColor = [UIColor clearColor];\n            button;\n        });\n    }\n    return _%@;\n}\n\n",class,varName,varName,varName,varName];
    } else if ([class isEqual:@"UILabel"]) {
        return @"";
    }else {
        return @"";
    }
    
//    return  [NSString stringWithFormat:@"- (%@ *)%@ {\n\tif(_%@ == nil) {\n\t\t_%@ = [[%@ alloc] init];\n\t}\n\treturn _%@;\n}\n\n", class, varName, varName, varName, class, varName];
}

//-(NSString*)ButtonInstantiate:(NSString*)varName

//代码识别
-(NSMutableDictionary*)makeClassAndVar:(NSString*)selectedString {
    if (selectedString) {
        NSMutableDictionary *dictionary=[[NSMutableDictionary alloc]init];
        @try {
            NSString *searchedString = selectedString;
            NSRange searchedRange;
            searchedRange = NSMakeRange(0, [searchedString length]);
            NSString *pattern = @"\\)\\s?(.*?)\\s?\\*([^\\*]+);";
            NSError *error = nil;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
            NSArray *matches = [regex matchesInString:searchedString options:0 range:searchedRange];
            
            for (NSTextCheckingResult *match in matches) {
                
                NSString *class = [searchedString substringWithRange:[match rangeAtIndex:1]];
                NSString *varName = [searchedString substringWithRange:[match rangeAtIndex:2]];
                [dictionary setValue:class forKey:varName];
                
            }
            return dictionary;
        } @catch (NSException *exception) {
            NSLog(@"%@", exception.reason);
            return nil;
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
