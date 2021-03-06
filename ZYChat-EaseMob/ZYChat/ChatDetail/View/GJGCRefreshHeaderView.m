//
//  GJGCRefreshHeaderView.m
//  ZYChat
//
//  Created by ZYVincent QQ:1003081775 on 14-11-11.
//  Copyright (c) 2014年 ZYProSoft. All rights reserved.
//

#import "GJGCRefreshHeaderView.h"


@interface GJGCRefreshHeaderView ()

@property (nonatomic,strong)UIView *refreshHeadView;

@property (nonatomic,strong)UILabel *refreshTextLabel;

@property (nonatomic,strong)UIImageView *arrowImgView;

@property (nonatomic,strong)UIActivityIndicatorView *activeView;

@property (nonatomic,strong)UILabel *refreshTimeLabel;

@property (nonatomic)BOOL isDragging;

@property (nonatomic,assign)BOOL isLoadingMore;

@end

@implementation GJGCRefreshHeaderView

- (instancetype)init{
    
    if (self = [super init]) {
        
        [self setupStrings];
        
        [self setupSubViews];

    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        
        [self setupStrings];
        
        [self setupSubViews];

    }
    return self;
}

- (void)setupStrings
{
    //设置静态字符串
    self.pullString = @"下拉刷新";
    self.releaseString = @"释放刷新";
    self.refreshString = @"         正在刷新...";
}

- (void)setupSubViews
{
    self.gjcf_height = REFRESH_HEAD_HEIGHT;

    //设置标签
    //self.refreshTextLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, GJCFSystemScreenWidth, REFRESH_HEAD_HEIGHT/2+REFRESH_HEAD_HEIGHT/4)];
    self.refreshTextLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 10, GJCFSystemScreenWidth, REFRESH_HEAD_HEIGHT/2+REFRESH_HEAD_HEIGHT/4)];
    self.refreshTextLabel.backgroundColor = [UIColor clearColor];
    self.refreshTextLabel.font = [UIFont boldSystemFontOfSize:14];
    self.refreshTextLabel.textAlignment = NSTextAlignmentCenter;
    self.refreshTextLabel.textColor = TEXT_COLOR;
    
    //设置时间
    self.refreshTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, REFRESH_HEAD_HEIGHT/2, GJCFSystemScreenWidth, 25)];
    self.refreshTimeLabel.backgroundColor = [UIColor clearColor];
    self.refreshTimeLabel.font = [UIFont systemFontOfSize:12.0];
    self.refreshTimeLabel.textAlignment = NSTextAlignmentCenter;
    self.refreshTimeLabel.textColor = TEXT_COLOR;
    //设置箭头位置
    self.arrowImgView = [[UIImageView alloc]init];
    self.arrowImgView.frame = CGRectMake(floorf((REFRESH_HEAD_HEIGHT - 27)/2), floorf((REFRESH_HEAD_HEIGHT - 44)/2), 27, 44);
    
    //设置活动指示
    self.activeView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    //self.activeView.frame = CGRectMake(floorf((REFRESH_HEAD_HEIGHT -20)/2+60), floorf((REFRESH_HEAD_HEIGHT-20)/2-7), 20, 20);
    self.activeView.frame = CGRectMake(floorf((REFRESH_HEAD_HEIGHT -20)/2+60+40), floorf((REFRESH_HEAD_HEIGHT-20)/2-7)+10, 20, 20);
    self.activeView.hidesWhenStopped = YES;
    
    //添加到头部视图
    [self addSubview:self.refreshTextLabel];
    [self addSubview:self.arrowImgView];
    [self addSubview:self.activeView];
    [self addSubview:self.refreshTimeLabel];
    
    self.frame = CGRectMake(0,-REFRESH_HEAD_HEIGHT, GJCFSystemScreenWidth, REFRESH_HEAD_HEIGHT);
}

- (void)setupChatFooterStyle
{
    self.refreshTextLabel.hidden = YES;
    self.arrowImgView.hidden = YES;
    self.refreshTimeLabel.hidden = YES;
    self.activeView.gjcf_centerX = GJCFSystemScreenWidth/2;
    
}

#pragma mark - ScrollView代理

//开始拖动得时得方法
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.isLoading) {
        return;
    }
    self.isDragging = YES;
}

//拖动中得方法
- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    
    if (self.isLoading) {
        
        // 更改tableView被包围得头部边距
        scrollView.contentInset = UIEdgeInsetsMake(REFRESH_HEAD_HEIGHT, 0, 0, 0);//头部包围距离为偏移距离
        
    } else if (self.isDragging && scrollView.contentOffset.y < 0) {
        
        // 更改箭头得方向
        [UIView beginAnimations:nil context:NULL];
        
        if (scrollView.contentOffset.y < -REFRESH_HEAD_HEIGHT) {
            
            // 下拉超过了头部视图高度翻转箭头
            self.refreshTextLabel.text = self.releaseString;
            
            [self.arrowImgView layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
            
        } else { // 已经在头部视图高度范围内则翻转箭头
            
            self.refreshTextLabel.text = self.pullString;
            
            [self.arrowImgView layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
        }
        [UIView commitAnimations];
    }
}

//结束拖动后开始减速得方法
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (self.isLoading) {
        return;
    }
    
    self.isDragging = NO;
    
    if (scrollView.contentOffset.y <= -REFRESH_HEAD_HEIGHT) {
        
        [self startLoadingForScrollView:scrollView];
        
    }
    
}

//开始转动刷新
- (void)startLoadingForScrollView:(UIScrollView *)scrollView
{
    self.isLoading = YES;

    //显示头部,用动画缓和
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];
    scrollView.contentInset = UIEdgeInsetsMake(REFRESH_HEAD_HEIGHT, 0, 0, 0);//改变tableview头部被包围状态
    self.refreshTextLabel.text = self.refreshString;
    self.arrowImgView.hidden = YES;
    [self.activeView startAnimating];
    [UIView commitAnimations];
    
    //执行刷新方法
    if (self.delegate && [self.delegate respondsToSelector:@selector(refreshHeaderViewTriggerRefresh:)]) {
        [self.delegate refreshHeaderViewTriggerRefresh:self];
    }
}

- (void)stopLoadingForScrollView:(UIScrollView *)scrollView isAnimation:(BOOL)isAnimation
{
    self.isLoading = NO;
//    [UIView beginAnimations:nil context:nil];
//    [UIView setAnimationDuration:0.3];
//    [UIView setAnimationDelegate:self];
//    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:)];//动画结束完执行完更改头部视图得内容
    [self animationDidStop:nil finished:YES];
    scrollView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);//恢复头部零距离包围tableview
    [self.arrowImgView layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
//    [UIView commitAnimations];
}

//停止刷新
- (void)stopLoadingForScrollView:(UIScrollView *)scrollView
{
    self.isLoading = NO;
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:)];//动画结束完执行完更改头部视图得内容
    scrollView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);//恢复头部零距离包围tableview
    [self.arrowImgView layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
    [UIView commitAnimations];
}

//animationdelegate
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    //刷新停止后需要恢复头部视图得内容
    self.refreshTextLabel.text = self.pullString;
    self.arrowImgView.hidden = NO;
    [self.activeView stopAnimating];
}

@end
