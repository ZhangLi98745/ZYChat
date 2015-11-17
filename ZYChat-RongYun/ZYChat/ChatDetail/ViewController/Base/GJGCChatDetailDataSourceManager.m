//
//  GJGCChatDetailDataSourceManager.m
//  ZYChat
//
//  Created by ZYVincent on 14-11-3.
//  Copyright (c) 2014年 ZYProSoft. All rights reserved.
//

#import "GJGCChatDetailDataSourceManager.h"

static dispatch_queue_t _messageSenderQueue;

@interface GJGCChatDetailDataSourceManager ()<IEMChatProgressDelegate>

@end

@implementation GJGCChatDetailDataSourceManager

- (instancetype)initWithTalk:(GJGCChatFriendTalkModel *)talk withDelegate:(id<GJGCChatDetailDataSourceManagerDelegate>)aDelegate
{
    if (self = [super init]) {
        
        _taklInfo = talk;
        
        _uniqueIdentifier = [NSString stringWithFormat:@"GJGCChatDetailDataSourceManager_%@",GJCFStringCurrentTimeStamp];
        
        self.delegate = aDelegate;
        
        [self initState];
        
    }
    return self;
}

#pragma mark - 插入新消息

- (void)insertNewMessageWithStartIndex:(NSInteger)startIndex Count:(NSInteger)count
{
    NSMutableArray *willUpdateIndexPaths = [NSMutableArray array];
    for (NSInteger index = startIndex + 1; index < startIndex + count; index++ ) {
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        [willUpdateIndexPaths addObject:indexPath];
    }
    if (willUpdateIndexPaths.count > 0) {
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(dataSourceManagerRequireUpdateListTable:insertIndexPaths:)]) {
            [self.delegate dataSourceManagerRequireUpdateListTable:self insertIndexPaths:willUpdateIndexPaths];
        }
    }
}

- (void)dealloc
{
    [GJCFNotificationCenter removeObserver:self];
}

#pragma mark - 内部接口

- (NSArray *)heightForContentModel:(GJGCChatContentBaseModel *)contentModel
{
    if (!contentModel) {
        return nil;
    }
    
    Class cellClass;
    
    switch (contentModel.baseMessageType) {
        case GJGCChatBaseMessageTypeSystemNoti:
        {
            GJGCChatSystemNotiModel *notiModel = (GJGCChatSystemNotiModel *)contentModel;
            cellClass = [GJGCChatSystemNotiConstans classForNotiType:notiModel.notiType];
        }
            break;
        case GJGCChatBaseMessageTypeChatMessage:
        {
            GJGCChatFriendContentModel *chatContentModel = (GJGCChatFriendContentModel *)contentModel;
            cellClass = [GJGCChatFriendConstans classForContentType:chatContentModel.contentType];
        }
            break;
        default:
            break;
    }
    
    GJGCChatBaseCell *baseCell = [[cellClass alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    [baseCell setContentModel:contentModel];
    
    CGFloat contentHeight = [baseCell heightForContentModel:contentModel];
    CGSize  contentSize = [baseCell contentSize];
    
    return @[@(contentHeight),[NSValue valueWithCGSize:contentSize]];
}

- (void)initState
{
    if (!_messageSenderQueue) {
        _messageSenderQueue = dispatch_queue_create("_gjgc_message_sender_queue", DISPATCH_QUEUE_SERIAL);
    }
    
    self.isFinishFirstHistoryLoad = NO;
    
    self.chatListArray = [[NSMutableArray alloc]init];
    
    self.timeShowSubArray = [[NSMutableArray alloc]init];

    /* 重试所有发送状态消息 */
    [self performSelector:@selector(reTryAllSendingStateMsg) withObject:nil afterDelay:2.0f];
    
}

#pragma mark - update UI By Dispatch_Source_t

#pragma mark - 公开接口

- (NSInteger)totalCount
{
    return self.chatListArray.count;
}

- (NSInteger)chatContentTotalCount
{
    return self.chatListArray.count - self.timeShowSubArray.count;
}

- (Class)contentCellAtIndex:(NSInteger)index
{
    Class resultClass;
    
    if (index > self.totalCount - 1) {
        return nil;
    }
    
    /* 分发信息 */
    GJGCChatContentBaseModel *contentModel = [self.chatListArray objectAtIndex:index];
    
    switch (contentModel.baseMessageType) {
        case GJGCChatBaseMessageTypeSystemNoti:
        {
            GJGCChatSystemNotiModel *notiModel = (GJGCChatSystemNotiModel *)contentModel;
            resultClass = [GJGCChatSystemNotiConstans classForNotiType:notiModel.notiType];
        }
            break;
        case GJGCChatBaseMessageTypeChatMessage:
        {
            GJGCChatFriendContentModel *messageModel = (GJGCChatFriendContentModel *)contentModel;
            resultClass = [GJGCChatFriendConstans classForContentType:messageModel.contentType];
        }
            break;
        default:
            
            break;
    }
    
    return resultClass;
}

- (NSString *)contentCellIdentifierAtIndex:(NSInteger)index
{
    if (index > self.totalCount - 1) {
        return nil;
    }
    
    NSString *resultIdentifier = nil;
    
    /* 分发信息 */
    GJGCChatContentBaseModel *contentModel = [self.chatListArray objectAtIndex:index];
    
    switch (contentModel.baseMessageType) {
        case GJGCChatBaseMessageTypeSystemNoti:
        {
            GJGCChatSystemNotiModel *notiModel = (GJGCChatSystemNotiModel *)contentModel;
            resultIdentifier = [GJGCChatSystemNotiConstans identifierForNotiType:notiModel.notiType];
        }
            break;
        case GJGCChatBaseMessageTypeChatMessage:
        {
            GJGCChatFriendContentModel *messageModel = (GJGCChatFriendContentModel *)contentModel;
            resultIdentifier = [GJGCChatFriendConstans identifierForContentType:messageModel.contentType];
        }
            break;
        default:
        
            break;
    }
    
    return resultIdentifier;
}

- (GJGCChatContentBaseModel *)contentModelAtIndex:(NSInteger)index
{
    return [self.chatListArray objectAtIndex:index];
}

- (CGFloat)rowHeightAtIndex:(NSInteger)index
{
    if (index > self.totalCount - 1) {
        return 0.f;
    }
    
    GJGCChatContentBaseModel *contentModel = [self contentModelAtIndex:index];
    
    return contentModel.contentHeight;
}

- (NSNumber *)updateContentModel:(GJGCChatContentBaseModel *)contentModel atIndex:(NSInteger)index
{
    NSArray *contentHeightArray = [self heightForContentModel:contentModel];
    contentModel.contentHeight = [[contentHeightArray firstObject] floatValue];
    contentModel.contentSize = [[contentHeightArray lastObject] CGSizeValue];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        
        [self updateMsgContentHeightWithContentModel:contentModel];

    });
    
    [self.chatListArray replaceObjectAtIndex:index withObject:contentModel];
    
    return @(contentModel.contentHeight);
}

- (void)updateAudioFinishRead:(NSString *)localMsgId
{
    
}

- (void)updateMsgContentHeightWithContentModel:(GJGCChatContentBaseModel *)contentModel
{
    
}

//- (void)updateContentModelStateWithMsgModel:(GJGCIMMsgBaseModel *)msgModel
//{
//    NSInteger contentItemIndex = [self getContentModelIndexByLocalMsgId:GJCFStringFromInt([msgModel.localMsgId intValue])];
//    if (contentItemIndex == NSNotFound) {
//        return;
//    }
//    
//    GJGCChatContentBaseModel *baseModel = [self contentModelAtIndex:contentItemIndex];
//    
//    if (baseModel) {
//        
//        baseModel.sendStatus = [msgModel.state intValue];
//        
//        /* 发送失败 */
//        if ([msgModel.state intValue] == 0) {
//            
//            if ([msgModel isKindOfClass:[GJGCIMFriendMsgModel class]]) {
//                GJGCIMFriendMsgModel *friendMsg = (GJGCIMFriendMsgModel *)msgModel;
//                baseModel.faildReason = friendMsg.faildReason;
//                baseModel.faildType = [friendMsg.faildType intValue];
//            }
//            if ([msgModel isKindOfClass:[GJGCIMPostMsgModel class]]) {
//                GJGCIMPostMsgModel *postMsg = (GJGCIMPostMsgModel *)msgModel;
//                baseModel.faildReason = postMsg.faildReason;
//                baseModel.faildType = [postMsg.faildType intValue];
//            }
//            if ([msgModel isKindOfClass:[GJGCIMGroupMsgModel class]]) {
//                GJGCIMGroupMsgModel *groupMsg = (GJGCIMGroupMsgModel *)msgModel;
//                baseModel.faildReason = groupMsg.faildReason;
//                baseModel.faildType = [groupMsg.faildType intValue];
//            }
//
//        }
//        
//        [self.chatListArray replaceObjectAtIndex:contentItemIndex withObject:baseModel];
//
//        if (self.delegate && [self.delegate respondsToSelector:@selector(dataSourceManagerRequireUpdateListTable:reloadForUpdateMsgStateAtIndex:)]) {
//            [self.delegate dataSourceManagerRequireUpdateListTable:self reloadForUpdateMsgStateAtIndex:contentItemIndex];
//        }
//    }
//}

- (GJGCChatContentBaseModel *)contentModelByLocalMsgId:(NSString *)localMsgId
{
    for (int i = 0 ; i < self.chatListArray.count ; i ++) {
        
        GJGCChatContentBaseModel *contentItem = [self.chatListArray objectAtIndex:i];
        
        if ([contentItem.localMsgId isEqualToString:localMsgId]) {
            
            return contentItem;
            
            break;
        }
    }
    return nil;
}

- (void)updateContentModelValuesNotEffectRowHeight:(GJGCChatContentBaseModel *)contentModel atIndex:(NSInteger)index
{
    if ([contentModel.class isSubclassOfClass:[GJGCChatFriendContentModel class]]) {
        
        GJGCChatFriendContentModel *friendChatModel = (GJGCChatFriendContentModel *)contentModel;
        
        if (friendChatModel.contentType == GJGCChatFriendContentTypeAudio && friendChatModel.isPlayingAudio) {
            
            [self updateAudioFinishRead:friendChatModel.localMsgId];
        }
    }
    [self.chatListArray replaceObjectAtIndex:index withObject:contentModel];
}

- (NSNumber *)addChatContentModel:(GJGCChatContentBaseModel *)contentModel
{
    contentModel.contentSourceIndex = self.chatListArray.count;
    
    NSNumber *heightNew = [NSNumber numberWithFloat:contentModel.contentHeight];
    
    if (contentModel.contentHeight == 0) {
        
        NSArray *contentHeightArray = [self heightForContentModel:contentModel];
        contentModel.contentHeight = [[contentHeightArray firstObject] floatValue];
        contentModel.contentSize = [[contentHeightArray lastObject] CGSizeValue];
        
        [self updateMsgContentHeightWithContentModel:contentModel];
        
    }else{
        
        NSLog(@"不需要计算内容高度:%f",contentModel.contentHeight);
        
    }
    
    [self.chatListArray addObject:contentModel];
    
    return heightNew;
}

- (void)removeChatContentModelAtIndex:(NSInteger)index
{
    [self.chatListArray removeObjectAtIndex:index];
}

- (void)readLastMessagesFromDB
{
    
}

- (NSArray *)deleteMessageAtIndex:(NSInteger)index
{
    return nil;
}

- (void)updateAudioUrl:(NSString *)audioUrl withLocalMsg:(NSString *)localMsgId toId:(NSString *)toId
{
    
}

- (void)updateImageUrl:(NSString *)imageUrl withLocalMsg:(NSString *)localMsgId toId:(NSString *)toId
{
    
}

#pragma mark - 加载历史消息

- (void)trigglePullHistoryMsg
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        /* 底部加载特效 */
        if (self.delegate && [self.delegate respondsToSelector:@selector(dataSourceManagerRequireTriggleLoadMore:)]) {
            [self.delegate dataSourceManagerRequireTriggleLoadMore:self];
        }
        
        GJCFWeakSelf weakSelf = self;
        
//        [[GJGCIMRecieveMsgManager shareManager]getFirstPullHistoryMsgWithMsgType:GJGCTalkTypeString(self.taklInfo.talkType) toId:self.taklInfo.toId observer:self.uniqueIdentifier isNeedFistPullBlock:^(BOOL checkResult, BOOL isFinishFirstPull) {
//            
//            if (checkResult) {
//                
//                if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(dataSourceManagerRequireFinishLoadMore:)]) {
//                    
//                    weakSelf.isFinishFirstHistoryLoad = YES;
//                    
//                    [weakSelf.delegate dataSourceManagerRequireFinishLoadMore:weakSelf];
//                }
//            }
//            
//        }];
    });
}


- (void)trigglePullHistoryMsgForEarly
{
    NSLog(@"聊天详情触发拉取更早历史消息 talkType:%@ toId:%@",GJGCTalkTypeString(self.taklInfo.talkType),self.taklInfo.toId);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        if (self.chatListArray && [self.chatListArray count] > 0) {
            
            /* 去掉时间模型，找到最上面一条消息内容 */
            GJGCChatFriendContentModel *lastMsgContent;
            for (int i = 0; i < self.totalCount ; i++) {
                GJGCChatFriendContentModel *item = (GJGCChatFriendContentModel *)[self contentModelAtIndex:i];
                
                if (!item.isTimeSubModel) {
                    lastMsgContent = item;
                    break;
                }
                
            }
            
            /* 最后一条消息的发送时间 */
            long long lastMsgSendTime;
            if (lastMsgContent) {
                lastMsgSendTime = lastMsgContent.sendTime;
            }else{
                lastMsgSendTime = 0;
            }
            
//            NSArray *localHistroyMsgArray = [[GJGCIMRecieveMsgManager shareManager]getEarlyHistoryMsgWithLastMsgTime:lastMsgSendTime withMsgType:GJGCTalkTypeString(self.taklInfo.talkType) toId:self.taklInfo.toId observer:self.uniqueIdentifier];
//            
//            if (localHistroyMsgArray && localHistroyMsgArray.count > 0 ) {
//                
//                [self pushAddMoreMsg:localHistroyMsgArray];
//            }
//                        
//        }else{
//            
//            [[GJGCIMRecieveMsgManager shareManager]getLastSubMsgEarlyMsgWithMsgType:GJGCTalkTypeString(self.taklInfo.talkType) toId:self.taklInfo.toId observer:self.uniqueIdentifier];
//            
        }
        
    });
    
}

- (void)pushAddMoreMsg:(NSArray *)array
{
    
}

#pragma mark - 所有内容重排时间

- (void)resortAllChatContentBySendTime
{
    
    /* 去掉时间区间model */
    for (GJGCChatContentBaseModel *contentBaseModel in self.timeShowSubArray) {
        
        /* 去掉时间区间重新排序 */
        if (contentBaseModel.isTimeSubModel) {
            [self.chatListArray removeObject:contentBaseModel];
        }
        
    }
    
    NSArray *sortedArray = [self.chatListArray sortedArrayUsingSelector:@selector(compareContent:)];
    [self.chatListArray removeAllObjects];
    [self.chatListArray addObjectsFromArray:sortedArray];
    
    /* 重设时间区间 */
    [self updateAllMsgTimeShowString];
}

- (void)resortAllSystemNotiContentBySendTime
{
    NSArray *sortedArray = [self.chatListArray sortedArrayUsingSelector:@selector(compareContent:)];
    [self.chatListArray removeAllObjects];
    [self.chatListArray addObjectsFromArray:sortedArray];
}

#pragma mark - 重设第一条消息的msgId
- (void)resetFirstAndLastMsgId
{
    /* 重新设置第一条消息的Id */
    if (self.chatListArray.count > 0) {
        
        GJGCChatContentBaseModel *firstMsgContent = [self.chatListArray firstObject];
        
        NSInteger nextMsgIndex = 0;
        
        while (firstMsgContent.isTimeSubModel) {
            
            nextMsgIndex++;
            
            firstMsgContent = [self.chatListArray objectAtIndex:nextMsgIndex];
            
        }
        
        self.lastFirstLocalMsgId = firstMsgContent.localMsgId;
    }
}

#pragma mark - 更新所有聊天消息的时间显示块

- (void)updateAllMsgTimeShowString
{
  /* 始终以当前时间为计算基准 最后最新一条时间开始往上计算*/
  [self.timeShowSubArray removeAllObjects];
  
    NSTimeInterval firstMsgTimeInterval = 0;
    
    GJGCChatFriendContentModel *currentTimeSubModel = nil;
    for (NSInteger i = 0; i < self.totalCount; i++) {
        
        GJGCChatFriendContentModel *contentModel = [self.chatListArray objectAtIndex:i];
        if (contentModel.contentType == GJGCChatFriendContentTypeTime) {
            NSLog(@"contentModel is time :%@",contentModel.uniqueIdentifier);
        }
        
        NSString *timeString = [GJGCChatSystemNotiCellStyle timeAgoStringByLastMsgTime:contentModel.sendTime lastMsgTime:firstMsgTimeInterval];
        
        if (timeString) {
            
            /* 创建时间块，插入到数据源 */
            firstMsgTimeInterval = contentModel.sendTime;
            
            GJGCChatFriendContentModel *timeSubModel = [GJGCChatFriendContentModel timeSubModel];
            timeSubModel.baseMessageType = GJGCChatBaseMessageTypeChatMessage;
            timeSubModel.contentType = GJGCChatFriendContentTypeTime;
            timeSubModel.timeString = [GJGCChatSystemNotiCellStyle formateTime:timeString];
            NSArray *contentHeightArray = [self heightForContentModel:timeSubModel];
            timeSubModel.contentHeight = [[contentHeightArray firstObject] floatValue];
            timeSubModel.sendTime = contentModel.sendTime;
            timeSubModel.timeSubMsgCount = 1;
            
            currentTimeSubModel = timeSubModel;
            
            contentModel.timeSubIdentifier = timeSubModel.uniqueIdentifier;
            
            [self.chatListArray replaceObjectAtIndex:i withObject:contentModel];
            
            [self.chatListArray insertObject:timeSubModel atIndex:i];
            
            i++;
        
            [self.timeShowSubArray addObject:timeSubModel];
            
        }else{
            
            contentModel.timeSubIdentifier = currentTimeSubModel.uniqueIdentifier;
            currentTimeSubModel.timeSubMsgCount = currentTimeSubModel.timeSubMsgCount + 1;
            
            [self updateContentModelByUniqueIdentifier:contentModel];
            [self updateContentModelByUniqueIdentifier:currentTimeSubModel];
            
        }
    }
}

- (void)updateContentModelByUniqueIdentifier:(GJGCChatContentBaseModel *)contentModel
{
    for (NSInteger i = 0; i < self.totalCount ; i++) {
        
        GJGCChatContentBaseModel *itemModel = [self.chatListArray objectAtIndex:i];
        
        if ([itemModel.uniqueIdentifier isEqualToString:contentModel.uniqueIdentifier]) {
            
            [self.chatListArray replaceObjectAtIndex:i withObject:contentModel];
            
            break;
        }
    }
}

- (GJGCChatContentBaseModel *)timeSubModelByUniqueIdentifier:(NSString *)identifier
{
    for (GJGCChatContentBaseModel *timeSubModel in self.chatListArray) {
        
        if ([timeSubModel.uniqueIdentifier isEqualToString:identifier]) {
            
            return timeSubModel;
        }
    }
    return nil;
}

- (void)updateTheNewMsgTimeString:(GJGCChatContentBaseModel *)contentModel
{
    NSTimeInterval lastSubTimeInteval;
     GJGCChatFriendContentModel *lastTimeSubModel = [self.timeShowSubArray lastObject];
    if (self.timeShowSubArray.count > 0) {
        lastSubTimeInteval = lastTimeSubModel.sendTime;
    }else{
        lastSubTimeInteval = 0;
    }
    
    NSString *timeString = [GJGCChatSystemNotiCellStyle timeAgoStringByLastMsgTime:contentModel.sendTime lastMsgTime:lastSubTimeInteval];
    
    if (timeString) {
        
        GJGCChatFriendContentModel *newLastTimeSubModel = [GJGCChatFriendContentModel timeSubModel];
        newLastTimeSubModel.baseMessageType = GJGCChatBaseMessageTypeChatMessage;
        newLastTimeSubModel.contentType = GJGCChatFriendContentTypeTime;
        newLastTimeSubModel.sendTime = contentModel.sendTime;
        newLastTimeSubModel.timeString = [GJGCChatSystemNotiCellStyle formateTime:timeString];
        NSArray *contentHeightArray = [self heightForContentModel:newLastTimeSubModel];
        newLastTimeSubModel.contentHeight = [[contentHeightArray firstObject] floatValue];
        newLastTimeSubModel.timeSubMsgCount = 1;
        
        contentModel.timeSubIdentifier = newLastTimeSubModel.uniqueIdentifier;
        
        [self updateContentModelByUniqueIdentifier:contentModel];
        
        [self.chatListArray insertObject:newLastTimeSubModel atIndex:self.totalCount - 1];
        
        [self.timeShowSubArray addObject:newLastTimeSubModel];

    }else{
        
        contentModel.timeSubIdentifier = lastTimeSubModel.uniqueIdentifier;
        lastTimeSubModel.timeSubMsgCount = lastTimeSubModel.timeSubMsgCount + 1;
        
        [self updateContentModelByUniqueIdentifier:contentModel];
        [self updateContentModelByUniqueIdentifier:lastTimeSubModel];
        
    }
    
}

/* 删除某条消息，更新下一条消息的区间 */
- (NSString *)updateMsgContentTimeStringAtDeleteIndex:(NSInteger)index
{
    GJGCChatContentBaseModel *contentModel = [self.chatListArray objectAtIndex:index];
    
    GJGCChatContentBaseModel *timeSubModel = [self timeSubModelByUniqueIdentifier:contentModel.timeSubIdentifier];
    timeSubModel.timeSubMsgCount = timeSubModel.timeSubMsgCount - 1;
    
    if (timeSubModel.timeSubMsgCount == 0) {
        
        return timeSubModel.uniqueIdentifier;
        
    }else{
        
        [self updateContentModelByUniqueIdentifier:timeSubModel];
        
        return nil;
    }
}

- (void)removeContentModelByIdentifier:(NSString *)identifier
{
    for (GJGCChatContentBaseModel *item in self.chatListArray) {
        
        if ([item.uniqueIdentifier isEqualToString:identifier]) {
            
            [self.chatListArray removeObject:item];
            
            break;
        }
    }
}

- (void)removeTimeSubByIdentifier:(NSString *)identifier
{
    [self removeContentModelByIdentifier:identifier];
    
    for (GJGCChatContentBaseModel *item in self.timeShowSubArray) {
        
        if ([item.uniqueIdentifier isEqualToString:identifier]) {
            
            [self.timeShowSubArray removeObject:item];
            
            break;
        }
    }
}

- (NSInteger)getContentModelIndexByLocalMsgId:(NSString *)msgId
{
    NSInteger resultIndex = NSNotFound;
 
    if (GJCFStringIsNull(msgId)) {
        return resultIndex;
    }
    
    for ( int i = 0; i < self.chatListArray.count; i++) {
        
        GJGCChatContentBaseModel *contentModel = [self.chatListArray objectAtIndex:i];
        
        if ([contentModel.localMsgId isEqualToString:msgId]) {
            
            resultIndex = i;
            
            break;
        }

    }
    
    return resultIndex;
}

- (GJGCChatContentBaseModel *)contentModelByMsgId:(NSString *)msgId
{
    NSInteger resultIndex = [self getContentModelIndexByLocalMsgId:msgId];
    
    if (resultIndex != NSNotFound) {
        
        return [self.chatListArray objectAtIndex:resultIndex];
    }
    return nil;
}

#pragma mark - 更细最后一条消息

- (void)updateLastMsg:(GJGCChatFriendContentModel *)contentModel
{
    NSMutableString *chatContent = [NSMutableString string];
    BOOL isGroupChat = contentModel.talkType == GJGCChatFriendTalkTypeGroup;
    
    if (isGroupChat && contentModel.contentType !=GJGCChatFriendContentTypeMini) {
        [chatContent appendFormat:@"%@:",contentModel.senderName.string];
    }
    
    if (contentModel.contentType == GJGCChatFriendContentTypeImage) {
        [chatContent appendString:@"[图片]"];
    }
    if (contentModel.contentType == GJGCChatFriendContentTypeAudio) {
        [chatContent appendString:@"[语音]"];
    }
    if (contentModel.contentType == GJGCChatFriendContentTypeText) {
        [chatContent appendString:contentModel.originTextMessage];
    }
    if (contentModel.contentType == GJGCChatFriendContentTypeMini) {
        [chatContent appendString:contentModel.simpleTextMessage.string];
    }
    if (contentModel.contentType == GJGCChatFriendContentTypePost) {
        [chatContent appendString:@"[帖子]"];
    }
    if (contentModel.contentType == GJGCChatFriendContentTypeMemberWelcome) {
        [chatContent appendString:contentModel.titleString.string];
    }
    if (contentModel.contentType == GJGCChatFriendContentTypeGroupCall) {
        [chatContent appendString:contentModel.summonTitleString.string];
    }
    if (contentModel.contentType == GJGCChatFriendContentTypeReplyGroupCall) {
        [chatContent appendString:contentModel.acceptSummonTitle.string];
    }
    if (contentModel.contentType == GJGCChatFriendContentTypeGif) {
        NSDictionary *relationDict = [NSDictionary dictionaryWithContentsOfFile:GJCFMainBundlePath(@"gifLocal.plist")];
        
        NSString *gifName = [relationDict objectForKey:contentModel.gifLocalId];
        
        if (GJCFStringIsNull(gifName)) {
            gifName = @"表情";
        }
        
        [chatContent appendFormat:@"[%@]",gifName];
    }
    if (contentModel.contentType == GJGCChatFriendContentTypeDriftBottle) {
        
        [chatContent appendString:contentModel.driftBottleContentString.string];
        
        contentModel.isRead = YES;
    }
    
    //如果是自己的消息，始终认为是已读的，不管是不是来自漫游消息
    if (contentModel.isFromSelf) {
        contentModel.isRead = YES;
    }
    
    /* 更新最后一条消息内容 */
    if (chatContent) {
        
//        [[GJGCMsgBoxInterfaseHandle getChatListInterfase]updateChatListWithToId:self.taklInfo.toId msgType:GJGCTalkTypeString(self.taklInfo.talkType) title:self.taklInfo.toUserName content:chatContent contentType:GJGCContentTypeToString(contentModel.contentType) isRead:contentModel.isRead updateTime:contentModel.sendTime state:contentModel.sendStatus];
    }
}

- (void)updateLastMsgForRecentTalk
{
    GJGCChatFriendContentModel *contentModel = [self.chatListArray lastObject];
    [self updateLastMsg:contentModel];
}

- (void)updateLastSystemMessageForRecentTalk
{
//    GJGCChatSystemNotiModel *notiModel = [self.chatListArray lastObject];
//    
//    GJGCIMFriendSystemModel *msgModel = [[GJGCFriendSystemMsgDBAPI share] getMsgByLocalMsgId:notiModel.localMsgId];
//    
//    if (msgModel) {
//        
//        NSString *notiContent = [GJGCChatSystemNotiConstans formateChatSystemGroupNotiMsgWithModel:msgModel];
//        
//        if (notiContent) {
//            
//            [[GJGCMsgBoxInterfaseHandle getChatListInterfase] updateChatListWithToId:self.taklInfo.toId msgType:GJGCTalkTypeString(self.taklInfo.talkType) title:self.taklInfo.toUserName content:notiContent contentType:msgModel.contentType isRead:msgModel.isRead updateTime:notiModel.sendTime state:notiModel.sendStatus];
//        }
//    }
}

#pragma mark - 重新发送所有正在发送状态的消息

- (void)reTryAllSendingStateMsg
{

}

- (void)reTryAllSendingStateMsgDetailAction
{
    
}

#pragma mark - 清除过早历史消息

- (void)clearOverEarlyMessage
{
    if (self.totalCount > 40) {
        [self.chatListArray removeObjectsInRange:NSMakeRange(0, self.totalCount - 40)];
        if (self.delegate && [self.delegate respondsToSelector:@selector(dataSourceManagerRequireUpdateListTable:)]) {
            [self.delegate dataSourceManagerRequireUpdateListTable:self];
        }
    }
}

#pragma mark - 重新尝试取本地消息
- (NSArray *)reTryGetLocalMessageWhileHistoryMessageIsSubMessagesOfLocalMessages
{
    /* 去掉时间模型，找到最上面一条消息内容 */
    GJGCChatFriendContentModel *lastMsgContent;
    for (int i = 0; i < self.totalCount ; i++) {
        GJGCChatFriendContentModel *item = (GJGCChatFriendContentModel *)[self contentModelAtIndex:i];
        if (!item.isTimeSubModel) {
            lastMsgContent = item;
            break;
        }
    }
    
    /* 最后一条消息的发送时间 */
    long long lastMsgSendTime;
    if (lastMsgContent) {
        lastMsgSendTime = lastMsgContent.sendTime;
    }else{
        lastMsgSendTime = 0;
    }
    
    NSArray *resultArray =  [NSArray array];
    
    return resultArray;
}

#pragma mark - 格式化消息内容

//- (GJGCChatFriendContentType)formateChatFriendContent:(GJGCChatFriendContentModel *)chatContentModel withMsgModel:(GJGCIMMsgBaseModel *)msgModel
//{
//    GJGCChatFriendContentType type = GJGCChatFriendContentTypeNotFound;
//    
//    /* 图片消息 */
//    if ([msgModel.contentType isEqualToString:@"pic"]) {
//        
//        chatContentModel.contentType = GJGCChatFriendContentTypeImage;
//        type = chatContentModel.contentType;
//        
//        NSDictionary *imageInfo = [NSJSONSerialization JSONObjectWithData:[msgModel.contents dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
//        
//        if ([imageInfo isKindOfClass:[NSDictionary class]]) {
//            chatContentModel.imageMessageUrl = [imageInfo objectForKey:@"pic_url"];
//        }else{
//            type = GJGCChatFriendContentTypeNotFound;
//        }
//    }
//    
//    /* 语音消息 */
//    if ([msgModel.contentType isEqualToString:@"sound"]) {
//        
//        chatContentModel.contentType = GJGCChatFriendContentTypeAudio;
//        type = chatContentModel.contentType;
//        chatContentModel.isRead = msgModel.isRead;
//        
//        NSDictionary *audioInfo = [NSJSONSerialization JSONObjectWithData:[msgModel.contents dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
//        
//        if ([audioInfo isKindOfClass:[NSDictionary class]]) {
//            
//            if (![audioInfo[@"src"] hasPrefix:@"http://"]) {
//                
//                chatContentModel.audioModel.localStorePath = [[GJCFCachePathManager shareManager]mainAudioCacheFilePath:audioInfo[@"src"]];
//                
//            }else{
//                
//                chatContentModel.audioModel.remotePath = [audioInfo objectForKey:@"src"];
//                chatContentModel.audioModel.localStorePath = [[GJCFCachePathManager shareManager]mainAudioCacheFilePathForUrl:[audioInfo objectForKey:@"src"]];
//            }
//            chatContentModel.audioModel.duration = [[audioInfo objectForKey:@"duration"]floatValue];
//            chatContentModel.audioDuration = [GJGCChatFriendCellStyle formateAudioDuration:GJCFStringFromInt(chatContentModel.audioModel.duration)];
//            
//        }else{
//            
//            type = GJGCChatFriendContentTypeNotFound;
//            
//        }
//        
//    }
//    
//    /* 文本消息 */
//    if ([msgModel.contentType isEqualToString:@"text"]) {
//        
//        chatContentModel.contentType = GJGCChatFriendContentTypeText;
//        type = chatContentModel.contentType;
//        
//        if ([msgModel.contents isKindOfClass:[NSString class]]) {
//            
//            if (!GJCFNSCacheGetValue(msgModel.contents)) {
//                [GJGCChatFriendCellStyle formateSimpleTextMessage:msgModel.contents];
//            }
//            chatContentModel.originTextMessage = msgModel.contents;
//            
//        }else{
//            
//            type = GJGCChatFriendContentTypeNotFound;
//        }
//        
//    }
//    
//    /* mini 消息 */
//    if ([msgModel.contentType isEqualToString:@"mini"] || [msgModel.contentType isEqualToString:@"notFriendMini"]) {
//        
//        chatContentModel.contentType = GJGCChatFriendContentTypeMini;
//        type = chatContentModel.contentType;
//        
//        if ([msgModel.contents isKindOfClass:[NSString class]]) {
//            
//            chatContentModel.simpleTextMessage = [GJGCChatFriendCellStyle formateMinMessage:msgModel.contents];
//            
//        }else{
//            
//            type = GJGCChatFriendContentTypeNotFound;
//        }
//        
//    }
//    
//    /* 帖子消息 */
//    if ([msgModel.contentType isEqualToString:@"url"]) {
//        
//        chatContentModel.contentType = GJGCChatFriendContentTypePost;
//        type = chatContentModel.contentType;
//        
//        NSDictionary *userInfo = [msgModel.contents gjgc_toDictionary];
//        
//        if ([userInfo isKindOfClass:[NSDictionary class]]) {
//            
//            NSString *postTitle = [userInfo objectForKey:@"title"];
//            NSString *postId = [userInfo objectForKey:@"id"];
//            NSString *postImg = [userInfo objectForKey:@"img"];
//            NSString *postSrc = [userInfo objectForKey:@"src"];
//            NSString *postPrice = [userInfo objectForKey:@"price"];
//            NSString *postPuid = [userInfo objectForKey:@"puid"];
//            chatContentModel.postId = postId;
//            chatContentModel.postTitle = postTitle;
//            chatContentModel.postImg = postImg;
//            chatContentModel.imageMessageUrl = postImg;
//            chatContentModel.postSrc = postSrc;
//            chatContentModel.postPrice = postPrice;
//            chatContentModel.postAttributedTitle = [GJGCChatFriendCellStyle formatePostTitle:postTitle];
//            chatContentModel.postPuid = postPuid;
//            chatContentModel.postPicIdentifier = [NSString stringWithFormat:@"%@_%@",self.taklInfo.toId,msgModel.localMsgId];
//            
//        }
//    }
//    
//    /**
//     *  新人欢迎card
//     */
//    if ([msgModel.contentType isEqualToString:@"personalcard"]) {
//        
//        chatContentModel.contentType = GJGCChatFriendContentTypeMemberWelcome;
//        type = chatContentModel.contentType;
//                
//        /**
//         *  解析个人信息
//         */
//        NSDictionary *userInfo = [[msgModel.contents gjgc_toDictionary]objectForKey:@"showContent"];
//        chatContentModel.titleString = [GJGCChatFriendCellStyle formateTitleString:userInfo[@"title"]];
//        chatContentModel.nameString = [GJGCChatFriendCellStyle formateNameString:userInfo[@"nickName"]];
//        chatContentModel.senderName = [GJGCChatFriendCellStyle formateGroupChatSenderName:userInfo[@"nickName"]];
//        
//        chatContentModel.sex = [[userInfo objectForKey:@"gender"] isEqualToString:@"男"]? 1:0;
//        chatContentModel.userId = [userInfo objectForKey:@"userId"];
//        
//        NSDate *birthDate = GJCFDateFromString([userInfo objectForKey:@"birthday"]);
//        
//        NSString *ageString = GJCFDateBirthDayToAge(birthDate);
//        NSString *age = nil;
//        if (![ageString hasSuffix:@"岁"]) {
//            age = @"0";
//        }else{
//            age = [ageString stringByReplacingOccurrencesOfString:@"岁" withString:@""];
//        }
//        
//        if (chatContentModel.sex == 0 && [age intValue] <= 28) {
//            
//            chatContentModel.titleString = [GJGCChatFriendCellStyle formateYoungWomenNameString:userInfo[@"title"]];
//            
//        }else{
//            
//            chatContentModel.titleString = [GJGCChatFriendCellStyle formateNameString:userInfo[@"title"]];
//            
//        }
//        
//        if (chatContentModel.sex == 1) {
//            
//            chatContentModel.ageString = [GJGCChatFriendCellStyle formateManAge:age];
//            
//        }else{
//            
//            chatContentModel.ageString = [GJGCChatFriendCellStyle formateWomenAge:age];
//        }
//        
//        chatContentModel.starString = [GJGCChatFriendCellStyle formateStarName:GJCFDateToConstellation(birthDate)];
//    }
//    
//    /**
//     *  群主召唤
//     */
//    if ([msgModel.contentType isEqualToString:@"SummonCard"]) {
//        
//        chatContentModel.contentType = GJGCChatFriendContentTypeGroupCall;
//        type = chatContentModel.contentType;
//        
//        NSDictionary *userInfo = [msgModel.contents gjgc_toDictionary];
//        
//        NSLog(@"summonCard title:%@",userInfo[@"title"]);
//        
//        NSLog(@"summonCard desc:%@",userInfo[@"desc"]);
//
//        NSString *groupCallTitle = [userInfo objectForKey:@"title"];
//        
//        NSString *groupCallContent = [userInfo objectForKey:@"desc"];
//        
//        chatContentModel.summonTitleString = [GJGCChatFriendCellStyle formateGroupCallTitle:groupCallTitle];
//        
//        chatContentModel.summonContentString = [GJGCChatFriendCellStyle formateGroupCallContent:groupCallContent];
//    
//    }
//    
//    /**
//     *  接受召唤
//     */
//    if ([msgModel.contentType isEqualToString:@"acceptSummonCard"]) {
//        
//        chatContentModel.contentType = GJGCChatFriendContentTypeReplyGroupCall;
//        type = chatContentModel.contentType;
//        
//        NSDictionary *userInfo = [[msgModel.contents gjgc_toDictionary] objectForKey:@"showContent"];
//        
//        NSString *acceptTitle = [userInfo objectForKey:@"title"];
//        
//        chatContentModel.acceptSummonTitle = [GJGCChatFriendCellStyle formateGroupCallTitle:acceptTitle];
//
//    }
//    
//    /**
//     *  gif表情
//     */
//    if ([msgModel.contentType isEqualToString:@"gif"]) {
//        
//        chatContentModel.contentType = GJGCChatFriendContentTypeGif;
//        type = chatContentModel.contentType;
//        
//        NSString *gifLocalId = [[msgModel.contents gjgc_toDictionary]objectForKey:@"local_id"];
//        
//        chatContentModel.gifLocalId = gifLocalId;
//    }
//    
//    /**
//     *  漂流瓶
//     */
//    if ([msgModel.contentType isEqualToString:@"driftbottlecard"]) {
//        
//        chatContentModel.contentType = GJGCChatFriendContentTypeDriftBottle;
//        type = chatContentModel.contentType;
//        
//        NSDictionary *userInfo = [msgModel.contents gjgc_toDictionary];
//
//        NSString *content = [userInfo objectForKey:@"content"];
//        
//        chatContentModel.driftBottleContentString = [GJGCChatFriendCellStyle formateDriftBottleContent:content];
//        chatContentModel.imageMessageUrl = [userInfo objectForKey:@"pic"];
//    }
//    
//    return type;
//}

- (void)sendMesssage:(GJGCChatFriendContentModel *)messageContent
{
    messageContent.sendStatus = GJGCChatFriendSendMessageStatusSending;
    EMMessage *mesage = [self sendMessageContent:messageContent];
    messageContent.easeMessageTime = mesage.timestamp;
    messageContent.sendTime = [[NSDate date]timeIntervalSince1970];
    
    //收到消息
    [self addChatContentModel:messageContent];
    
    [self updateTheNewMsgTimeString:messageContent];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(dataSourceManagerRequireUpdateListTable:)]) {
        
        [self.delegate dataSourceManagerRequireUpdateListTable:self];
        
    }
}

#pragma mark -  环信发送消息过程

- (EMMessage *)sendMessageContent:(GJGCChatFriendContentModel *)messageContent
{
    EMMessage *sendMessage = nil;
    switch (messageContent.contentType) {
        case GJGCChatFriendContentTypeText:
        {
            sendMessage = [self sendTextMessage:messageContent];
        }
            break;
        case GJGCChatFriendContentTypeAudio:
        {
            sendMessage = [self sendAudioMessage:messageContent];
        }
            break;
        case GJGCChatFriendContentTypeImage:
        {
            sendMessage = [self sendImageMessage:messageContent];
        }
            break;
        default:
            break;
    }
    
    GJCFWeakSelf weakSelf = self;
    EMMessage *resultMessage = [[EaseMob sharedInstance].chatManager asyncSendMessage:sendMessage progress:self prepare:^(EMMessage *message, EMError *error) {
        
    } onQueue:_messageSenderQueue completion:^(EMMessage *message, EMError *error) {
        
        GJGCChatFriendSendMessageStatus status = GJGCChatFriendSendMessageStatusSending;
        switch (message.deliveryState) {
            case eMessageDeliveryState_Pending:
            case eMessageDeliveryState_Delivering:
            {
                status = GJGCChatFriendSendMessageStatusSending;
            }
                break;
            case eMessageDeliveryState_Delivered:
            {
                status = GJGCChatFriendSendMessageStatusSuccess;
            }
                break;
            case eMessageDeliveryState_Failure:
            {
                status = GJGCChatFriendSendMessageStatusFaild;
            }
                break;
            default:
                break;
        }
        
        [weakSelf updateMessageState:message state:status];
        
    } onQueue:_messageSenderQueue];
        
    return resultMessage;
}

- (EMMessage *)sendTextMessage:(GJGCChatFriendContentModel *)messageContent
{
    EMChatText *chatText = [[EMChatText alloc]initWithText:messageContent.originTextMessage];
    EMTextMessageBody *messageBody = [[EMTextMessageBody alloc]initWithChatObject:chatText];
    EMMessage *aMessage = [[EMMessage alloc]initWithReceiver:messageContent.toId bodies:@[messageBody]];
    
    return aMessage;
}

- (EMMessage *)sendAudioMessage:(GJGCChatFriendContentModel *)messageContent
{
    EMChatVoice *voice = [[EMChatVoice alloc] initWithFile:messageContent.audioModel.localStorePath displayName:@"[语音]"];
    voice.duration = messageContent.audioModel.duration;
    EMVoiceMessageBody *body = [[EMVoiceMessageBody alloc] initWithChatObject:voice];
    
    // 生成message
    EMMessage *message = [[EMMessage alloc] initWithReceiver:messageContent.toId bodies:@[body]];
    
    return message;
}

- (EMMessage *)sendImageMessage:(GJGCChatFriendContentModel *)messageContent
{
    NSString *filePath = [[GJCFCachePathManager shareManager]mainImageCacheFilePath:messageContent.imageLocalCachePath];
    EMChatImage *imgChat = [[EMChatImage alloc] initWithUIImage:[UIImage imageWithContentsOfFile:filePath] displayName:@"[图片]"];
    EMImageMessageBody *body = [[EMImageMessageBody alloc] initWithChatObject:imgChat];
    
    // 生成message
    EMMessage *message = [[EMMessage alloc] initWithReceiver:messageContent.toId bodies:@[body]];
    
    return message;
}

#pragma mark - 聊天消息发送回调

- (void)setProgress:(float)progress forMessage:(EMMessage *)message forMessageBody:(id<IEMMessageBody>)messageBody
{
    
}

- (void)updateMessageState:(EMMessage *)theMessage state:(GJGCChatFriendSendMessageStatus)status
{
    GJGCChatFriendContentModel *findContent = nil;
    NSInteger findIndex = NSNotFound;
    
    for (NSInteger index =0 ;index < self.chatListArray.count;index++) {
        
        GJGCChatFriendContentModel *content = [self.chatListArray objectAtIndex:index];
        
        if (content.easeMessageTime == theMessage.timestamp) {
            
            findContent = content;
            findIndex = index;
            
            break;
        }
    }
    
    if (findContent && findIndex !=NSNotFound) {
        
        findContent.sendStatus = status;
        [self.chatListArray replaceObjectAtIndex:findIndex withObject:findContent];
        
        [self.delegate dataSourceManagerRequireUpdateListTable:self reloadAtIndex:findIndex];
    }
}

@end
