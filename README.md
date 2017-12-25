# applePay
苹果支付 

大概步骤：
1、从自己的服务器拿到数据 A；
2、从苹果服务器拿到一个数组 B；
3、检查数组B 是否包含数据 A；
4、如果包含，开始支付；
5、返回支付结果。

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
    
