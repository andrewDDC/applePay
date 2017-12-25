//
//  ViewController.swift
//  ApplePayDemo
//
//  Created by wyl on 2017/12/11.
//  Copyright © 2017年 wyl. All rights reserved.
//

import UIKit

// 1、导入头文件
import StoreKit

class ViewController: UIViewController, KKIpaManagerDelegate {
    
    fileprivate var btn = UIButton(type: .custom)
    
    deinit {
        KKIpaManager.shared.delegate = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }

    fileprivate func setupUI() {
        
        // 2、创建请求按钮

        btn.frame = CGRect(x: 100, y: 100, width: 100, height: 44)
        btn.setTitle("苹果支付", for: UIControlState.normal)
        btn.backgroundColor = UIColor.red
        view.addSubview(btn)
        
        btn.addTarget(self, action: #selector(applePay(_:)), for: .touchUpInside)
        
        KKIpaManager.shared.cleanData()
        KKIpaManager.shared.delegate = self
    }

    @objc fileprivate func applePay(_ sender: UIButton) {
        
        KKIpaManager.shared.buyProduct("com.kankan.video.product.two", orderID: "1234")
    }
    
    func applePayDidPay(_ isSuccess: Bool, with error: String?) {
        print(isSuccess ? "成功":"失败")
        
        if let error = error {
            print("解释信息 -- \(error)")
        }
    }

}
