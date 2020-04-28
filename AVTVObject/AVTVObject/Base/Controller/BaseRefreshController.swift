//
//  BaseRefreshController.swift
//  GKGame_Swift
//
//  Created by wangws1990 on 2019/9/30.
//  Copyright © 2019 wangws1990. All rights reserved.
//

import UIKit
import Alamofire
let RefreshPageStart : Int = (1)
let RefreshPageSize  : Int = (20)
let defaultDataEmpty : UIImage = UIImage.init(named: "icon_data_empty") ?? UIImage.init();
let defaultNetError  : UIImage = UIImage.init(named: "icon_net_error") ?? UIImage.init();
let FDMSG_Home_DataRefresh  :String             = "数据加载中...";
let FDMSG_Home_DataEmpty    :String             = "数据空空如也...";
let FDNoNetworkMsg          :String             = "无网络连接,请检查网络设置";
struct ATRefreshOption :OptionSet {
    public var rawValue: Int
    static var None          : ATRefreshOption{return ATRefreshOption(rawValue: 0)}
    static var Header        : ATRefreshOption{return ATRefreshOption(rawValue: 1<<0)};
    static var Footer        : ATRefreshOption{return ATRefreshOption(rawValue: 1<<1)};
    static var AutoHeader    : ATRefreshOption{return ATRefreshOption(rawValue: 1<<2)};
    static var AutoFooter    : ATRefreshOption{return ATRefreshOption(rawValue: 1<<3)};
    static var DefaultHidden : ATRefreshOption{return ATRefreshOption(rawValue: 1<<4)};
    static var Default       : ATRefreshOption{return ATRefreshOption(rawValue: Header.rawValue|AutoHeader.rawValue|Footer.rawValue|DefaultHidden.rawValue)};
}
class BaseRefreshController: BaseViewController,DZNEmptyDataSetSource,DZNEmptyDataSetDelegate {
    weak open var scrollView : UIScrollView!;
    var _isRefreshing : Bool = false;
    var currentPage : Int = 0;
    var emptyImage : UIImage = defaultDataEmpty;
    var emptyTitle : String  = FDMSG_Home_DataEmpty;
    var isSetKVO : Bool = false;
    lazy var images: [UIImage] = {
        var images :[UIImage] = [];
        for i in 0...35{
            let image = UIImage.init(named:String("下拉loading_00") + String(i < 10 ? ("0"+String(i)) : String(i)));
            if image != nil {
                images.append(image!);
            }
        }
//        for i in 4...0{
//            let image = UIImage.init(named:String("loading")+String(i));
//            if image != nil {
//                images.append(image!);
//            }
//        }
        return images;
    }()
    var isRefreshing :Bool{
        set{
            _isRefreshing = newValue;
            if self.scrollView != nil {
                if self.scrollView!.isEmptyDataSetVisible {
                    self.reloadEmptyData();
                }
            }
        }get{
            return _isRefreshing;
        }
    }
    deinit {
//        self.scrollView.delegate = nil;
    }
    /**
    @brief 设置刷新控件 子类可在refreshData中发起网络请求, 请求结束后回调endRefresh结束刷新动作
    @param scrollView 刷新控件所在scrollView
    @param option 刷新空间样式
    */
    public func setupRefresh(scrollView:UIScrollView,options:ATRefreshOption){
        self.scrollView = scrollView;
        if options.rawValue == ATRefreshOption.None.rawValue {
            if self.responds(to: #selector(headerRefreshing)) {
                self.headerRefreshing();
            }
            return;
        }
        var value : Int = options.rawValue & ATRefreshOption.Header.rawValue;
        if value == 1  {
            let header : MJRefreshGifHeader = MJRefreshGifHeader.init(refreshingTarget: self, refreshingAction: #selector(headerRefreshing));
            header.stateLabel.isHidden = true;
            header.isAutomaticallyChangeAlpha = true;
            header.lastUpdatedTimeLabel.isHidden = true;
            if self.images.count > 0 {
                header.setImages([self.images.first as Any], for: .idle);
                header.setImages(self.images, duration: 0.35, for: .refreshing);
            }
            value = options.rawValue & ATRefreshOption.AutoHeader.rawValue;
            if value == 4 {
                self.headerRefreshing();
            }
            scrollView.mj_header = header;
        }
        value = options.rawValue & ATRefreshOption.Footer.rawValue;
        if value == 2 {
            let footer : MJRefreshAutoGifFooter = MJRefreshAutoGifFooter.init(refreshingTarget: self, refreshingAction: #selector(footerRefreshing));
            footer.triggerAutomaticallyRefreshPercent = -20;
            footer.stateLabel.isHidden = false;
            footer.labelLeftInset = -22;
            if self.images.count > 0 {
                footer.setImages([self.images.first as Any], for: .idle);
                footer.setImages(self.images, duration: 0.35, for: .refreshing);
            }
            footer.setTitle(" —— 我是有底线的 ——  ", for: .noMoreData);
            footer .setTitle("", for: .pulling);
            footer.setTitle("", for: .refreshing);
            footer.setTitle("", for: .willRefresh);
            footer.setTitle("", for: .idle);
            value = options.rawValue & ATRefreshOption.AutoFooter.rawValue;
            if value == 8 {
                if self.currentPage == 0 {
                    self.isRefreshing = true;
                }
                self.footerRefreshing();
            }
            value = options.rawValue & ATRefreshOption.DefaultHidden.rawValue;
            if value == 16 {
                footer.isHidden = true
            }
            scrollView.mj_footer = footer;
        }
        
    }
    /**
    设置空界面显示, 如果需要定制化 请实现协议 DZNEmptyDataSetSource, DZNEmptyDataSetDelegate
    tableView或者CollectionView数据reload后, 空界面展示可自动触发, 如需强制刷新, 请调用 [scrollView reloadEmptyDataSet];
    
    @param scrollView 空界面所在scrollView
    @param image 空界面图片
    @param title 空界面标题
    */
    public func setupEmpty(scrollView:UIScrollView){
        self.setupEmpty(scrollView: scrollView, image:nil, title:nil)
    }
    public func setupEmpty(scrollView:UIScrollView,image:UIImage? = nil,title:String? = nil){
        scrollView.emptyDataSetSource = self;
        scrollView.emptyDataSetDelegate = self;
        self.emptyImage = (image != nil) ?image!: defaultDataEmpty;
        self.emptyTitle = (title != nil) ?title!: FDMSG_Home_DataEmpty;
        if self.isSetKVO {
            return;
        }
        self.isSetKVO = true;
        weak var weakSelf = self;
        self.kvoController.observe(scrollView, keyPaths: ["contentSize","contentInset"], options: .new) { (observer, object, change) in
            NSObject.cancelPreviousPerformRequests(withTarget:weakSelf as Any, selector: #selector(weakSelf!.reloadEmptyData), object:nil)
            weakSelf!.perform(#selector(weakSelf!.reloadEmptyData), with:nil, afterDelay: 0.01)
        };
        
    }
    /**
    @brief 分页请求一开始page = 1
    @param page 当前页码
    */
    public func refreshData(page:Int){
        self.currentPage = page;
        DispatchQueue.main.asyncAfter(deadline: .now()+1) {
            if self.scrollView.mj_header != nil{
                if (self.scrollView?.mj_header.isRefreshing)! || (self.scrollView?.mj_header.isRefreshing)!{
                    self.endRefreshFailure();
                }
            }
        }
    }
    /**
    @brief 分页加载成功 是否有下一页数据
    */
    public func endRefresh(more:Bool){
        self.baseEndRefreshing();
        if self.scrollView.mj_footer == nil {
            return;
        }
        if more {
            self.scrollView?.mj_footer.state = .idle;
            self.scrollView?.mj_footer.isHidden = false;
            let footer:MJRefreshAutoStateFooter = self.scrollView?.mj_footer as! MJRefreshAutoStateFooter;
            footer.stateLabel.textColor = UIColor.init(hex: "666666");
        }else{
            self.scrollView?.mj_footer.state = .noMoreData;
            let footer:MJRefreshAutoStateFooter = self.scrollView?.mj_footer as! MJRefreshAutoStateFooter;
            footer.stateLabel.textColor = UIColor.init(hex: "999999");
            DispatchQueue.main.asyncAfter(deadline:.now()+0.01) {
                let height : CGFloat = (self.scrollView?.contentSize.height)!;
                let sizeHeight : CGFloat = (self.scrollView?.frame.size.height)!;
                let res : Bool = (self.currentPage == RefreshPageStart) || (height < sizeHeight);
                self.scrollView?.mj_footer.isHidden = res;
            }
        }
    }
    public func endRefreshFailure(){
        if self.currentPage > RefreshPageStart {
            self.currentPage = self.currentPage - 1;
        }
        self.baseEndRefreshing();
        if self.scrollView.mj_footer != nil {
                    if (self.scrollView?.mj_footer.isRefreshing)! {
                self.scrollView?.mj_footer.state = .idle;
            }
        }
        self.reloadEmptyData();
        
    }
    /**
    @brief 重新加载第一页
    */
    @objc public func headerRefreshing(){
        self.isRefreshing = true;
        if self.scrollView.mj_footer != nil{
            self.scrollView?.mj_footer.isHidden = true;
        }
        self.currentPage = RefreshPageStart;
        self.refreshData(page: self.currentPage);
    }
    @objc public func footerRefreshing(){
        self.currentPage = self.currentPage + 1;
        self.refreshData(page: self.currentPage);
    }
    public func baseEndRefreshing(){
        if self.scrollView.mj_header != nil {
            if (self.scrollView?.mj_header.isRefreshing)! {
                self.scrollView?.mj_header.endRefreshing();
            }
        }
        self.isRefreshing = false;
    }
    @objc public func reloadEmptyData(){
        if self.scrollView != nil {
            self.scrollView?.reloadEmptyDataSet();
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    func reachable()->Bool{
        return NetworkReachabilityManager.init()!.isReachable;
    }
    
    func loadImage()->UIImage{
        return UIImage.animatedImage(with: self.images, duration: 0.35)!;
    }
    //MARK:DZNEmptyDataSetSource
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        var text :String = self.isRefreshing ? FDMSG_Home_DataRefresh : self.emptyTitle;
        let dic :NSMutableDictionary = NSMutableDictionary.init();
        let font : UIFont = UIFont.systemFont(ofSize: 15);
        let color : UIColor = UIColor.init(hex: "999999")
        dic.setObject(color, forKey: NSAttributedString.Key.foregroundColor.rawValue as NSCopying);
        dic.setObject(font, forKey: NSAttributedString.Key.font.rawValue as NSCopying)
        if self.reachable() == false {
            text = FDNoNetworkMsg;
        }
        let att : NSAttributedString = NSAttributedString.init(string:"\r\n"+text, attributes:(dic as! [NSAttributedString.Key : Any]));
        return att;
    }
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return nil;
    }
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        let image : UIImage = self.isRefreshing ? self.loadImage() : self.emptyImage;
        return self.reachable() ? image : defaultNetError;
    }
    func emptyDataSetShouldAnimateImageView(_ scrollView: UIScrollView!) -> Bool {
        return false;
    }
    func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        return -NAVI_BAR_HIGHT/2
    }
    func spaceHeight(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        return 1;
    }
    func emptyDataSetShouldDisplay(_ scrollView: UIScrollView!) -> Bool {
        return true;
    }
    func emptyDataSetShouldAllowTouch(_ scrollView: UIScrollView!) -> Bool {
        return true;
    }
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView!) -> Bool {
        return !self.isRefreshing;
    }
    func emptyDataSet(_ scrollView: UIScrollView!, didTap view: UIView!) {
        if self.isRefreshing == false {
            self.headerRefreshing();
        }
    }

}
