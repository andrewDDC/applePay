//
//  KKIpaManager.swift
//

import StoreKit

protocol KKIpaManagerDelegate: class {
    func applePayDidPay(_ isSuccess:Bool, with error: String?)
}

class KKIpaManager: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    
    static let shared = KKIpaManager.init()
    private override init() {}
    
    fileprivate lazy var productIDs: [String] = []
    fileprivate lazy var orderIDs: [String] = []
    
    weak var delegate: KKIpaManagerDelegate?
    
    fileprivate var payQueue = DispatchQueue(label: "com.kankan.applepay.ipa")
    
    func buyProduct(_ productID: String, orderID: String) {
        
        SKPaymentQueue.default().add(self)
        
        if SKPaymentQueue.canMakePayments() {
            productIDs.append(productID)
            orderIDs.append(orderID)
            self.payQueue.sync {
                let neset = Set.init([productID])
                let request = SKProductsRequest(productIdentifiers: neset)
                request.delegate = self
                request.start()
            }
        } else {
            self.delegate?.applePayDidPay(false, with: "不允许这样支付")
        }
    }
    
    /// 在每次调用之前在 viewDidLoad 调用一下
    func cleanData() {
        self.productIDs.removeAll()
        self.orderIDs.removeAll()
    }
    
    // MARK: - SKProductsRequestDelegate
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let product = response.products
        
        var requestProduct:SKProduct?
        
        for product1 in product {
            if self.productIDs.count > 0, product1.productIdentifier.elementsEqual(self.productIDs.first!) {
                requestProduct = product1
                break
            }
        }
        
        if let product2 = requestProduct {
            self.payQueue.sync {
                let payment = SKPayment(product: product2)
                SKPaymentQueue.default().add(payment)
            }
        } else {
            self.delegate?.applePayDidPay(false, with: "没有匹配的数据")
            removeFirstDataObject()
        }
    }
    
    // MARK: - private
    fileprivate func removeFirstDataObject() {
        if self.productIDs.count > 0 {
            self.productIDs.removeFirst()
        }
        if self.orderIDs.count > 0 {
            self.orderIDs.removeFirst()
        }
    }
    
    
    // MARK: - SKRequestDelegate
    
    // 请求失败
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("请求失败了---\(error.localizedDescription)")
        self.delegate?.applePayDidPay(false, with: "请求苹果数据失败")
        removeFirstDataObject()
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
                completeTransaction(transaction)
                print("完成交易")
                break
            case .purchasing: // 商品添加进列表
                print("商品添加进列表")
                break
            case .restored:   // 已购买过商品
                print("已购买过商品")
                self.delegate?.applePayDidPay(false, with: "已购买过商品")
                removeFirstDataObject()
                SKPaymentQueue.default().finishTransaction(transaction)
                break
            case .failed:     // 交易失败
                print("交易失败--\(transaction.error?.localizedDescription ?? "")")
                failedTransaction(transaction)
                break
            case .deferred:   // 交易推迟
                print("交易推迟")
            }
        }
    }
    
    // MARK: -
    // MARK: - Complete transaction
    // 12-1 交易完成
    fileprivate func completeTransaction(_ transaction: SKPaymentTransaction) {
        // 处理相关的信息
        self.verifyPruchase(transaction)
    }
    
    // 12-2 交易失败
    fileprivate func failedTransaction(_ transaction: SKPaymentTransaction) {
        removeFirstDataObject()
        
        self.delegate?.applePayDidPay(false, with: "失败了 ---- \(transaction.error?.localizedDescription ?? "")")
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    /// 向自己的服务器验证购买凭证
    fileprivate func verifyPruchase(_ transaction: SKPaymentTransaction) {
        
        guard let orderID = orderIDs.first else {
            removeFirstDataObject()
            
            print(" -- 获取ID失败了 -- ")
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
        
        print("支付成功 receiptURL -- \(receiptURL)")
        print("支付成功 receipt -- \(receipt)")
        print("支付成功 appleid -- \(appleid)")
        
        //                        WEYHttpClient.sharedClient.verifyPruchase(orderID, sandbox: kInAppPurchasesEnvironment, appleid: appleid, receipt: receipt, completionHandler: { (diamond, error) -> Void in
        //                            if let error = error {
        //                                self.verifyPruchaseFailure(error.localizedDescription as NSString, orderID: orderID as NSString, appleID: appleid as NSString, receipt: receipt as NSString)
        //                            } else if let diamond = diamond {
        //                                self.diamond = diamond
        //                                self.status = WEYIAPPurchaseStatus.verifyPruchaseSucceeded
        //                                NotificationCenter.default.post(name: Notification.Name(rawValue: WEYIAPPurchaseNotification), object: self)
        //                            }
        //                        })
        
        SKPaymentQueue.default().finishTransaction(transaction)
        
        self.delegate?.applePayDidPay(true, with: "购买成功了")
        
        removeFirstDataObject()
    }
    
    fileprivate func verifyPruchaseFailure(_ msg: NSString?, orderID: NSString, appleID: NSString?, receipt: NSString?) {
        
        print("交易失败 --- ---- \(orderID)")
        
        removeFirstDataObject()
        
        self.delegate?.applePayDidPay(true, with: "购买失败了")
    }
    
}
