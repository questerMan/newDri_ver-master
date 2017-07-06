//
//  MAHeaderView.h
//  LiXinDriverTest
//
//  Created by lixin on 16/11/10.
//  Copyright © 2016年 陆遗坤. All rights reserved.
//


#import <UIKit/UIKit.h>

@protocol MAHeaderViewOffineDelegate;

@interface MAHeaderViewOffine : UIView

@property (nonatomic, assign) id<MAHeaderViewOffineDelegate> delegate;

@property (nonatomic, copy) NSString *text;

@property (nonatomic, assign, readonly) BOOL expanded;

@property (nonatomic, assign) NSInteger section;

- (id)initWithFrame:(CGRect)frame expanded:(BOOL)expanded;

@end

@protocol MAHeaderViewOffineDelegate <NSObject>

@optional

- (void)headerView:(MAHeaderViewOffine *)headerView section:(NSInteger)section expanded:(BOOL)expanded;

@end
