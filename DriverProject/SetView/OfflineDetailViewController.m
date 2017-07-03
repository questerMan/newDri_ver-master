//
//  OfflineDetailViewController.m
//  OfficialDemo3D
//
//  Created by xiaoming han on 14-5-5.
//  Copyright (c) 2014年 songjian. All rights reserved.
//

#import "OfflineDetailViewController.h"

#import "MAHeaderView.h"

#define kDefaultSearchkey       @"gz"
#define kSectionHeaderMargin    15.f
#define kSectionHeaderHeight    22.f
#define kTableCellHeight        42.f

NSString const *DownloadStageIsRunningKey2 = @"DownloadStageIsRunningKey";
NSString const *DownloadStageStatusKey2    = @"DownloadStageStatusKey";
NSString const *DownloadStageInfoKey2      = @"DownloadStageInfoKey";

@interface OfflineDetailViewController (SearchCity)

/* Returns a new array consisted of MAOfflineCity object for which match the key. */
- (NSArray *)citiesFilterWithKey:(NSString *)key;

@end

@interface OfflineDetailViewController ()<UITableViewDataSource, UITableViewDelegate, MAHeaderViewDelegate>
{
    char *_expandedSections;
    NSInteger _flag;
}

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *cities;
@property (nonatomic, strong) NSPredicate *predicate;

@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) NSArray *provinces;
@property (nonatomic, strong) NSArray *municipalities;

@property (nonatomic, strong) NSArray *CityArray;

@property (nonatomic, strong) NSMutableSet *downloadingItems;
@property (nonatomic, strong) NSMutableDictionary *downloadStages;

@property (nonatomic, assign) BOOL needReloadWhenDisappear;

@end

@implementation OfflineDetailViewController

@synthesize mapView   = _mapView;
@synthesize tableView = _tableView;
@synthesize cities = _cities;
@synthesize predicate = _predicate;

@synthesize sectionTitles = _sectionTitles;
@synthesize provinces = _provinces;
@synthesize municipalities = _municipalities;
@synthesize downloadingItems = _downloadingItems;
@synthesize downloadStages = _downloadStages;

@synthesize needReloadWhenDisappear = _needReloadWhenDisappear;

#pragma mark - Utility

- (void)checkNewestVersionAction
{
    [[MAOfflineMap sharedOfflineMap] checkNewestVersion:^(BOOL hasNewestVersion) {
        
        if (!hasNewestVersion)
        {
            return;
        }
        
        /* Manipulations to your application's user interface must occur on the main thread. */
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self setupTitle];
            
            [self setupCities];
            
            [self.tableView reloadData];
        });
    }];
}

- (UIButton *)downloadButton
{
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60.f, 40.f)];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    
    [button addTarget:self action:@selector(checkButtonTapped:event:) forControlEvents:UIControlEventTouchUpInside];
    
    return button;
}

- (NSIndexPath *)indexPathForSender:(id)sender event:(UIEvent *)event
{
    UIButton *button = (UIButton*)sender;
    
    UITouch *touch = [[event allTouches] anyObject];
    
    if (![button pointInside:[touch locationInView:button] withEvent:event])
    {
        return nil;
    }
    
    CGPoint touchPosition = [touch locationInView:self.tableView];
    
    return [self.tableView indexPathForRowAtPoint:touchPosition];
}

- (NSString *)cellLabelTextForItem:(MAOfflineItem *)item
{
    NSString *labelText = nil;
    
    
    if (item.itemStatus == MAOfflineItemStatusInstalled)
    {
        labelText = [item.name stringByAppendingString:@"(已安装)"];
    }
    else if (item.itemStatus == MAOfflineItemStatusExpired)
    {
        labelText = [item.name stringByAppendingString:@"(有更新)"];
    }
    else if (item.itemStatus == MAOfflineItemStatusCached)
    {
        labelText = [item.name stringByAppendingString:@"(缓存)"];
    }
    else
    {
        labelText = item.name;
    }
    
    return labelText;
}

- (NSString *)cellDetailTextForItem:(MAOfflineItem *)item
{
    NSString *detailText = nil;
    
    if (![self.downloadingItems containsObject:item])
    {
        if (item.itemStatus == MAOfflineItemStatusCached)
        {
            detailText = [NSString stringWithFormat:@"%lld/%lld", item.downloadedSize, item.size];
        }
        else
        {
            detailText = [NSString stringWithFormat:@"大小:%lld", item.size];
        }
    }
    else
    {
        NSMutableDictionary *stage  = [self.downloadStages objectForKey:item.adcode];
        
        MAOfflineMapDownloadStatus status = [[stage objectForKey:DownloadStageStatusKey2] intValue];
        
        switch (status)
        {
            case MAOfflineMapDownloadStatusWaiting:
            {
                detailText = @"等待";
                
                break;
            }
            case MAOfflineMapDownloadStatusStart:
            {
                detailText = @"开始";
                
                break;
            }
            case MAOfflineMapDownloadStatusProgress:
            {
                NSDictionary *progressDict = [stage objectForKey:DownloadStageInfoKey2];
                
                long long recieved = [[progressDict objectForKey:MAOfflineMapDownloadReceivedSizeKey] longLongValue];
                long long expected = [[progressDict objectForKey:MAOfflineMapDownloadExpectedSizeKey] longLongValue];
                
                detailText = [NSString stringWithFormat:@"%lld/%lld(%.1f%%)", recieved, expected, recieved/(float)expected*100];
                break;
            }
            case MAOfflineMapDownloadStatusCompleted:
            {
                detailText = @"下载完成";
                break;
            }
            case MAOfflineMapDownloadStatusCancelled:
            {
                detailText = @"取消";
                break;
            }
            case MAOfflineMapDownloadStatusUnzip:
            {
                detailText = @"解压中";
                break;
            }
            case MAOfflineMapDownloadStatusFinished:
            {
                detailText = @"结束";
                
                break;
            }
            default:
            {
                detailText = @"错误";
                
                break;
            }
        } // end switch

    }
    
    return detailText;
}

- (void)updateAccessoryViewForCell:(UITableViewCell *)cell item:(MAOfflineItem *)item
{
    UIButton *btn = (UIButton *)cell.accessoryView;
    
    if (item.itemStatus == MAOfflineItemStatusInstalled)
    {
        btn.hidden = YES;
    }
    else
    {
        btn.hidden = NO;
        
        if ([self.downloadingItems containsObject:item])
        {
            [btn setTitle:@"暂停" forState:UIControlStateNormal];
        }
        else
        {
            [btn setTitle:@"下载" forState:UIControlStateNormal];
        }
    }
}

- (void)updateCell:(UITableViewCell *)cell forItem:(MAOfflineItem *)item
{
    [self updateAccessoryViewForCell:cell item:item];
    
    cell.textLabel.text = [self cellLabelTextForItem:item];
    
    cell.detailTextLabel.text = [self cellDetailTextForItem:item];
}

- (void)download:(MAOfflineItem *)item atIndexPath:(NSIndexPath *)indexPath
{
    if (item == nil || item.itemStatus == MAOfflineItemStatusInstalled)
    {
        return;
    }
    
    NSLog(@"download :%@", item.name);
    
    [self.downloadingItems addObject:item];
    [self.downloadStages setObject:[NSMutableDictionary dictionary] forKey:item.adcode];
    
    [[MAOfflineMap sharedOfflineMap] downloadItem:item shouldContinueWhenAppEntersBackground:YES downloadBlock:^(MAOfflineItem *downloadItem, MAOfflineMapDownloadStatus downloadStatus, id info) {
        
        /* Manipulations to your application’s user interface must occur on the main thread. */
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSMutableDictionary *stage  = [self.downloadStages objectForKey:item.adcode];
            
            if (downloadStatus == MAOfflineMapDownloadStatusWaiting)
            {
                [stage setObject:[NSNumber numberWithBool:YES] forKey:DownloadStageIsRunningKey2];
            }
            else if(downloadStatus == MAOfflineMapDownloadStatusProgress)
            {
                [stage setObject:info forKey:DownloadStageInfoKey2];
            }
            else if(downloadStatus == MAOfflineMapDownloadStatusCancelled
                    || downloadStatus == MAOfflineMapDownloadStatusError
                    || downloadStatus == MAOfflineMapDownloadStatusFinished)
            {
                [stage setObject:[NSNumber numberWithBool:NO] forKey:DownloadStageIsRunningKey2];
                
                // clear
                [self.downloadingItems removeObject:item];
                [self.downloadStages removeObjectForKey:item.adcode];
            }
            
            [stage setObject:[NSNumber numberWithInt:downloadStatus] forKey:DownloadStageStatusKey2];
            
            /* Update UI. */
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            
            if (cell != nil)
            {
                [self updateCell:cell forItem:item];
            }
            
            if (downloadStatus == MAOfflineMapDownloadStatusFinished)
            {
                self.needReloadWhenDisappear = YES;
            }
        });
    }];
    
}

- (void)pause:(MAOfflineItem *)item
{
    NSLog(@"pause :%@", item.name);
    
    [[MAOfflineMap sharedOfflineMap] pauseItem:item];
}

- (void)handleItemAtIndexPath:(NSIndexPath *)indexPath
{
    MAOfflineItem *item = [self itemForIndexPath:indexPath];
    
    if (item == nil)
    {
        return;
    }
    
    if ([[MAOfflineMap sharedOfflineMap] isDownloadingForItem:item])
    {
        [self pause:item];
    }
    else
    {
        [self download:item atIndexPath:indexPath];
    }
}

- (MAOfflineItem *)itemForIndexPath:(NSIndexPath *)indexPath
{
    MAOfflineItem *item = nil;
    
    item = self.CityArray[indexPath.row];
    /*
    switch (indexPath.section)
    {
        case 0:
        {
            item = [MAOfflineMap sharedOfflineMap].nationWide;
            break;
        }
        case 1:
        {
            item = self.municipalities[indexPath.row];
            break;
        }
        case 2:
        {
            item = nil;
            break;
        }
        default:
        {
            MAOfflineProvince *pro = self.provinces[indexPath.section - self.sectionTitles.count];
            
            if (indexPath.row == 0)
            {
                item = pro; // 添加整个省
            }
            else
            {
                item = pro.cities[indexPath.row - 1]; // 添加市
            }
            
            break;
        }
    }
    */
    return item;
}

#pragma mark - UITableViewDataSource

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    //return section < self.sectionTitles.count ? kSectionHeaderHeight : kTableCellHeight;
    return 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
    //return self.sectionTitles.count + self.provinces.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    NSLog(@"[CityArray count]==%lu",(unsigned long)[self.CityArray count]);
    return [self.CityArray count];
    
    /*
    NSInteger number = 0;
    
    switch (section)
    {
        case 0:
        {
            number = 1;
            break;
        }
        case 1:
        {
            number = self.municipalities.count;
            break;
        }
        default:
        {
            if (_expandedSections[section])
            {
                MAOfflineProvince *pro = self.provinces[section - self.sectionTitles.count];
                
                // 加1用以下载整个省份的数据
                number = pro.cities.count + 1;
            }
            break;
        }
    }
    
    return number;
     */
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    /*
    NSString *theTitle = nil;
    
    if (section < self.sectionTitles.count)
    {
        theTitle = self.sectionTitles[section];
        
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), kSectionHeaderHeight)];
        headerView.backgroundColor = [UIColor lightGrayColor];
        
        UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(kSectionHeaderMargin, 0, CGRectGetWidth(headerView.bounds), CGRectGetHeight(headerView.bounds))];
        lb.backgroundColor = [UIColor clearColor];
        lb.text = theTitle;
        lb.textColor = [UIColor whiteColor];
        
        [headerView addSubview:lb];
        
        return headerView;
    }
    else
    {
        MAOfflineProvince *pro = self.provinces[section - self.sectionTitles.count];
        theTitle = pro.name;
        
        MAHeaderView *headerView = [[MAHeaderView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), kTableCellHeight) expanded:_expandedSections[section]];
        
        headerView.section = section;
        headerView.text = theTitle;
        headerView.delegate = self;
        
        return headerView;
    }
     */
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cityCellIdentifier = @"cityCellIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cityCellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cityCellIdentifier];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        cell.accessoryView = [self downloadButton];
    }
    
    //MAOfflineItem *item = self.municipalities[indexPath.row];//[self itemForIndexPath:indexPath];
    MAOfflineItem *item = self.CityArray[indexPath.row];
    [self updateCell:cell forItem:item];
    
    return cell;
}

//- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    if (indexPath.section < self.sectionTitles.count)
//    {
//        cell.backgroundColor = [UIColor whiteColor];
//    }
//    else
//    {
//        cell.backgroundColor = [UIColor lightGrayColor];
//    }
//}

#pragma mark - MAHeaderViewDelegate

- (void)headerView:(MAHeaderView *)headerView section:(NSInteger)section expanded:(BOOL)expanded
{
    _expandedSections[section] = expanded;
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Handle Action

- (void)checkButtonTapped:(id)sender event:(id)event
{
    NSIndexPath *indexPath = [self indexPathForSender:sender event:event];
    
    [self handleItemAtIndexPath:indexPath];
}

- (void)backAction
{
    [self cancelAllAction];
    
    [self dismissModalViewControllerAnimated:YES];
}

- (void)clearAllAction
{
    [[MAOfflineMap sharedOfflineMap] clearDisk];
    [self.tableView reloadData];
    
    NSLog(@"clear all");
}

- (void)cancelAllAction
{
    [[MAOfflineMap sharedOfflineMap] cancelAll];
    
    NSLog(@"pause all");

}

- (NSArray*)searchAction:(NSString *)code
{
    NSString *key=code;
    /* 搜索关键字支持 {城市中文名称, 拼音(不区分大小写), 拼音简写, cityCode, adCode}五种类型. */
    //NSString *key = kDefaultSearchkey;
    
    NSArray *result = [self citiesFilterWithKey:key];
    
    NSLog(@"key = %@, result count = %ld", key, (unsigned long)result.count);
    [result enumerateObjectsUsingBlock:^(MAOfflineCity *obj, NSUInteger idx, BOOL *stop) {
        NSLog(@"idx = %ld, cityName = %@, cityCode = %@, adCode = %@, pinyin = %@, jianpin = %@, size = %lld", (unsigned long)idx, obj.name, obj.cityCode,obj.adcode, obj.pinyin, obj.jianpin, obj.size);
    }];
    return result;
}

#pragma mark - Initialization

- (void)initNavigationBar
{
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(backAction)];
    
}

- (void)initToolBar
{
    UIBarButtonItem *flexbleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                 target:self
                                                                                 action:nil];
    
    UIBarButtonItem * cancelItem = [[UIBarButtonItem alloc] initWithTitle:@"取消全部"
                                                                    style:UIBarButtonItemStyleDone
                                                                   target:self
                                                                   action:@selector(cancelAllAction)];
    cancelItem.tintColor = [UIColor whiteColor];
    
    UIBarButtonItem * clearItem = [[UIBarButtonItem alloc] initWithTitle:@"清空全部"
                                                                   style:UIBarButtonItemStyleDone
                                                                  target:self
                                                                  action:@selector(clearAllAction)];
    clearItem.tintColor = [UIColor whiteColor];
    self.toolbarItems = [NSArray arrayWithObjects:flexbleItem, cancelItem, flexbleItem, clearItem,flexbleItem, nil];

}

- (void)initTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.tableView.delegate   = self;
    self.tableView.dataSource = self;
    self.tableView.frame=CGRectMake(0, CUSTOM_NAV_HEIGHT, self.view.width, self.view.height-CUSTOM_NAV_HEIGHT);
    [self.view addSubview:self.tableView];
}

- (void)setupCities
{
    self.sectionTitles = @[@"全国", @"直辖市", @"省份"];
    
    self.cities = [MAOfflineMap sharedOfflineMap].cities;
    self.provinces = [MAOfflineMap sharedOfflineMap].provinces;
    self.municipalities = [MAOfflineMap sharedOfflineMap].municipalities;
    NSLog(@"number====%lu",(unsigned long)[self.municipalities count]);
    self.downloadingItems = [NSMutableSet set];
    self.downloadStages = [NSMutableDictionary dictionary];
    
    
    if (_expandedSections != NULL)
    {
        free(_expandedSections);
        _expandedSections = NULL;
    }
    
    _expandedSections = (char *)malloc((self.sectionTitles.count + self.provinces.count) * sizeof(char));
    memset(_expandedSections, 0, (self.sectionTitles.count + self.provinces.count) * sizeof(char));
    
}

- (void)setupTitle
{
    self.navigationItem.title = [MAOfflineMap sharedOfflineMap].version;
}

- (void)setupPredicate
{
    self.predicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] $KEY OR cityCode CONTAINS[cd] $KEY OR jianpin CONTAINS[cd] $KEY OR pinyin CONTAINS[cd] $KEY OR adcode CONTAINS[cd] $KEY"];
}

#pragma mark - Life Cycle

- (id)init
{
    self = [super init];
    if (self)
    {
        [self setupCities];
        
        [self setupPredicate];
        
        //[self setupTitle];
        
        [self checkNewestVersionAction];
        _CityArray=[[NSArray alloc] init];
        
    }
    
    return self;
}

- (void)dealloc
{
    free(_expandedSections);
    _expandedSections = NULL;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor=[UIColor whiteColor];
    
    
    self.view.backgroundColor=[UIColor whiteColor];
    self.backLabel.text=@"离线地图 ";
    self.backLabel.textColor=Textwhite_COLOR;
    self.line.backgroundColor=[UIColor clearColor];
    [self.backButton addTarget:self action:@selector(BackMainView1) forControlEvents:UIControlEventTouchUpInside];
    
    
    
    
    //[self initNavigationBar];
    
    [self initTableView];
    
    //[self initToolBar];
    _flag=0;
   
}

-(void)BackMainView1
{
    [self.navigationController popViewControllerAnimated:YES];
    
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
//    self.navigationController.navigationBar.barStyle    = UIBarStyleBlack;
//    self.navigationController.navigationBar.translucent = NO;
//    
//    self.navigationController.toolbar.barStyle      = UIBarStyleBlack;
//    self.navigationController.toolbar.translucent   = NO;
//    [self.navigationController setToolbarHidden:NO animated:animated];
    
    
    // [self.tableView reloadData];
    
    [self getdata];
}

-(void)getdata
{

    QiFacade*       facade;
    facade=[QiFacade sharedInstance];
    _flag=[facade getCitysLIst];
    [facade addHttpObserver:self tag:_flag];
    [self showLoadingWithText:@"加载中..."];

}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.needReloadWhenDisappear)
    {
        [self.mapView reloadMap];
        
        self.needReloadWhenDisappear = NO;
    }
}

@end

@implementation OfflineDetailViewController (SearchCity)

/* Returns a new array consisted of MAOfflineCity object for which match the key. */
- (NSArray *)citiesFilterWithKey:(NSString *)key
{
    if (key.length == 0)
    {
        return nil;
    }
    
    NSPredicate *keyPredicate = [self.predicate predicateWithSubstitutionVariables:[NSDictionary dictionaryWithObject:key forKey:@"KEY"]];
    
    return [self.cities filteredArrayUsingPredicate:keyPredicate];
}

#pragma mark  加载


#pragma 网络处理

- (void)requestFinished:(NSDictionary*)response tag:(NSInteger)iRequestTag
{
    [self dismissLoading];
    NSLog(@"成功 /n%@",response);
    if(_flag!=0&&_flag==iRequestTag)
    {
        NSMutableArray *mutableArray=[[NSMutableArray alloc]init];
        NSArray *array=[response objectForKey:@"data"];
        for(NSDictionary *dic in array)
        {
            NSString *code=[dic objectForKey:@"code"];
            NSString *city=[dic objectForKey:@"city"];
            city= [city stringByReplacingOccurrencesOfString:@"市" withString:@""];
            NSArray *searchArray=[[self searchAction:city] mutableCopy];
            for(MAOfflineItem *item in searchArray)
            {
                if([city isEqualToString:item.name])
                {
                    MAOfflineItem *item2=[[MAOfflineItem alloc]init];
                    item2=item;
                    [mutableArray addObject:item2];
                    NSLog(@"item==%u",item.itemStatus);
                    break;
                }
            
            }
        }
        
        _CityArray=mutableArray;
        [_tableView reloadData];
    }
}


- (void)requestFailed:(NSDictionary*)response tag:(NSInteger)iRequestTag
{
    [self dismissLoading];
    NSString *Message=[response objectForKey:@"message"];
    if(Message!=nil)
    {
        NSLog(@"Message==%@",Message);
    }
    
    
    
    NSLog(@"失败 /n%@",response);
    
}





@end
