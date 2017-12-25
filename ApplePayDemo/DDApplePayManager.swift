//
//  DDApplePayManager.swift
//

import UIKit
import StoreKit

class DDIAPModel {
    var amount: String
    var sku: String
    
    init(_ amount: String, with sku: String) {
        self.amount = amount
        self.sku = sku
    }
}

protocol DDApplePayManagerDelegate:class {
    func applePayFailed(_ error: NSError?)
    func applePaySuccess()
}

class DDApplePayManager: NSObject {
    
    // 从苹果服务器获取的 product
    lazy var availableProducts: [SKProduct] = []

    lazy var orderIDs: [String] = []
    
    fileprivate var payQueue = DispatchQueue(label: "com.kankan.applepay.ipa")
    
    static let sharedInstance = DDApplePayManager.init()
    private override init() {}
    
    weak var delegate: DDApplePayManagerDelegate?
    
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    // MARK: -
    // MARK: - Public Methods
    // MARK: -
    
    // MARK: - 购买商品
    
    func buy(_ product: SKProduct, orderID: String) {
        payQueue.sync {
            self.orderIDs.append(orderID)
            let payment = SKMutablePayment(product: product)
            SKPaymentQueue.default().add(payment)
        }
    }
    
    // 获取 后台产品列表
    func fetchProductInformation(_ refresh: Bool, compalation:()->()) {
//        if SKPaymentQueue.canMakePayments() {
//
//            if !refresh && (self.iapItems.count > 0) && (self.iapItems.count == self.availableProducts.count) {
//                return true
//            }
//
//            WEYHttpClient.sharedClient.productList { (iapItemsFromResponse, error) -> Void in
//                if let error = error {
//                    self.errorMessage = error.localizedDescription
//                    self.status = WEYIAPProductRequestStatus.iapRequestFailed
//                    NotificationCenter.default.post(name: Notification.Name(rawValue: WEYIAPProductRequestNotification) , object: self)
//                } else {
//                    if let iapItems = iapItemsFromResponse {
//                        self.iapItems = iapItems
//                        let ids = iapItems.map({
//                            $0.sku
//                        })
//                        self.fetchProductInformationForIds(ids)
//                    }
//                }
//            }
//
//        } else {
//            self.errorMessage = NSLocalizedString("iap.alert.canMakePayments", comment: "")
//            self.status = WEYIAPProductRequestStatus.iapRequestFailed
//            NotificationCenter.default.post(name: Notification.Name(rawValue: WEYIAPProductRequestNotification) , object: self)
//        }
        
        // 数据请求之后
        self.fetchProductInformationForIds(["com.kankan.video.product.one", "com.kankan.video.product.one", "com.kankan.video.product.one"])
        compalation()
    }
    
    // MARK: - 请求苹果商品
    fileprivate func fetchProductInformationForIds(_ productIds: [String]) {
        if productIds.count > 0 {
            let request = SKProductsRequest(productIdentifiers: Set(productIds))
            request.delegate = self
            request.start()
        } else {
            print("商品ID为空")
        }
    }
    
    // MARK: - 商品恢复
    
}


extension DDApplePayManager: SKPaymentTransactionObserver, SKProductsRequestDelegate {
    
    // MARK: - SKProductsRequestDelegate
    
    // 9、接受到产品的返回信息，然后用返回的商品信息进行发起购买请求
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let product = response.products
        
        if product.count == 0 {
            print("苹果后台啥也没传回来")
            return
        }
        
        var requestProduct:SKProduct?
        
        for product1 in product {
            
            // 10、如果后台消费条目的ID与我们这里需求 请求的一样（用于确保订单的正确性）
            if product1.productIdentifier.elementsEqual("com.kankan.video.product.one") {
                requestProduct = product1
                break
            }
        }
        
        // 11、发起内购请求
        if let product2 = requestProduct {
            let payment = SKPayment(product: product2)
            SKPaymentQueue.default().add(payment)
            print("发起内购请求")
        } else {
            print("没有找到对应的ID 无法请求")
            let error = NSError.init(domain: "DDApplePay", code: 10002, userInfo: nil)
            delegate?.applePayFailed(error)
        }
        
    }
    
    // MARK: - SKRequestDelegate
    
    // 请求失败
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("请求失败了---\(error.localizedDescription)")
    }
    
    // 反馈请求的产品信息结束后
    func requestDidFinish(_ request: SKRequest) {
        print("信息反馈结束 --\(request.description)")
    }
    
    
    // MARK: - SKPaymentTransactionObserver
    
    // 12、购买结果的监听
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        for transaction in transactions {
            
            switch transaction.transactionState {
            case .purchased:  // 完成交易
                print("完成交易")
                break
            case .purchasing: // 商品添加进列表
                completeTransaction(transaction)
                print("商品添加进列表")
                break
            case .restored:   // 已购买过商品
                print("已购买过商品")
                SKPaymentQueue.default().finishTransaction(transaction)
                break
            case .failed:     // 交易失败
                print("交易失败")
                SKPaymentQueue.default().finishTransaction(transaction)
                break
            default:
                break
            }
        }
    }
    
    // MARK: -
    // MARK: - Complete transaction
    // 12-1 交易完成
    fileprivate func completeTransaction(_ transaction: SKPaymentTransaction) {
        payQueue.sync {
            self.verifyPruchase(transaction)
        }
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    // 12-2 交易失败
    fileprivate func failedTransaction(_ transaction: SKPaymentTransaction) {
        
        if let error = transaction.error {
            
        } else {
            
        }
        
        DispatchQueue(label: "com.wey.lock.iap", attributes: []).sync {
            // 处理相关的信息
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    /// 向自己的服务器验证购买凭证
    fileprivate func verifyPruchase(_ transaction: SKPaymentTransaction) {
        
        guard let orderID = orderIDs.first else {
            if self.orderIDs.count > 0 {
                self.orderIDs.removeFirst()
            }
            return
        }
        
        // 验证凭据，获取到苹果返回的交易凭据
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            verifyPruchaseFailure(nil, orderID: orderID as NSString, appleID: nil, receipt: nil)
            return
        }
        
        let receiptData = try? Data(contentsOf: receiptURL) // 从沙盒中获取到购买凭据
        
        guard let receipt = receiptData?.base64EncodedString(options: NSData.Base64EncodingOptions.endLineWithLineFeed) else {
            verifyPruchaseFailure(nil, orderID: orderID as NSString, appleID: nil, receipt: nil)
            return
        }
        
        guard let appleid = transaction.transactionIdentifier else {
            verifyPruchaseFailure(nil, orderID: orderID as NSString, appleID: nil, receipt: receipt as NSString)
            return
        }
        
        print("支付成功 -- \(appleid)")
        
        //                        WEYHttpClient.sharedClient.verifyPruchase(orderID, sandbox: kInAppPurchasesEnvironment, appleid: appleid, receipt: receipt, completionHandler: { (diamond, error) -> Void in
        //                            if let error = error {
        //                                self.verifyPruchaseFailure(error.localizedDescription as NSString, orderID: orderID as NSString, appleID: appleid as NSString, receipt: receipt as NSString)
        //                            } else if let diamond = diamond {
        //                                self.diamond = diamond
        //                                self.status = WEYIAPPurchaseStatus.verifyPruchaseSucceeded
        //                                NotificationCenter.default.post(name: Notification.Name(rawValue: WEYIAPPurchaseNotification), object: self)
        //                            }
        //                        })
        
        if self.orderIDs.count > 0 {
            self.orderIDs.removeFirst()
        }
        
    }
    
    fileprivate func verifyPruchaseFailure(_ msg: NSString?, orderID: NSString, appleID: NSString?, receipt: NSString?) {
        
        print("交易失败")
        if self.orderIDs.count > 0 {
            self.orderIDs.removeFirst()
        }
    }
    
    // 13、交易结束，当交易结束后还要去 App Store上验证支付信息是否正确，正确之后，则可以给用户展示我们的虚拟物品
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("走这里吗?")
    }
    
}
