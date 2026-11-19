# RegionSignalKit

iOS 15+ / Swift 5 的 CocoaPods 检查库，返回每项检查的通过、拒绝或无法确认。它只给出判断结果，不会自动关闭页面或拦截请求；请由接入方根据 `report.allowed` 执行相应操作。

## 本地接入

```ruby
pod 'RegionSignalKit', :path => '../RegionSignalKit'
```

发布到 CocoaPods 后可改成 `pod 'RegionSignalKit', '~> 0.1'`。也可使用仓库 URL 和 tag 安装；发布前需要替换 podspec 的仓库和作者信息。

```swift
import RegionSignalKit

let client = try RegionSignalKitClient(endpoint: URL(string: "https://your-domain.example/access-signals")!)
client.check { report in
    for item in report.results {
        print(item.check.rawValue, item.state.rawValue, item.detail)
    }
    DispatchQueue.main.async {
        if report.allowed {
            // 允许继续
        } else {
            // 拒绝或提示用户
        }
    }
}
```

**默认策略的所有检查都启用，无法确认即拒绝。由于 iOS 无法通用可靠地判断是否有 SIM 以及是否为实体卡，默认策略始终拒绝。** 如果业务接受这一限制，可显式关闭这两项：

```swift
var policy = Policy()
policy.enabledChecks.subtract([.simPresent, .physicalSIM])
client.check(policy: policy) { report in /* 使用 report.allowed */ }
```

也可以设置 `policy.unknownIsRejected = false` 允许无法确认的项通过，但这会影响所有启用的检查，包括 IP 和 VPN。明确拒绝的项仍会拒绝。

## 规则与限制

- IP 美国：服务端返回 ISO 3166-1 alpha-2 国家码 `US` 时拒绝。其他有效国家码通过，缺失或无效为无法确认。
- 设备地区美国：按当前系统区域的国家码判断。不是 GPS 位置，用户可以修改。
- 英语：按系统首选语言的主语言代码 `en` 判断，例如 `en-US`、`en-GB` 均拒绝。不是检查所有备选语言，也不是 App 的本地化语言。
- 地区与 IP 国家不一致：两个国家码不同时拒绝。旅行、漫游、IP 库错误等可能造成误判。
- VPN：服务端返回 `vpn: true` 或发现名称类似 VPN 隧道的活动接口时拒绝。接口启发式会误报，也可能漏报；`vpn: false` 仅表示服务商未判为 VPN，不能证明没有 VPN。其他代理和 iCloud Private Relay 等也未必能识别。
- SIM：通用公开 API 无法可靠检测有无 SIM 或区分实体卡与 eSIM；两项均为无法确认。不要把支持 eSIM 或运营商信息当作实体卡证明。
- 网络失败、非 2xx、响应格式错误、无效国家码或缺少字段：对应项为无法确认，默认拒绝。回调在 URLSession 队列上，更新 UI 时切换主线程。

## 服务端协议

必须由接入方提供 HTTPS GET 接口，依据服务器实际看到的客户端出口 IP 查询国家和 VPN 风险，响应例如：

```json
{"country_code":"CN","vpn":false}
```

`country_code` 和 `vpn` 可为 `null` 或省略，分别表示未知。不要相信客户端提交的 IP。IP 地理位置数据库和 VPN 风险服务需要自行选择并维护；IPv4/IPv6、反向代理和 CDN 的真实客户端 IP 配置也由服务端负责。请求可能包含用户 IP 等个人数据，接入方应自行处理隐私告知和服务端保护。

设备结果及最终授权应在可信服务端结合业务规则验证：客户端可被篡改，也无法保证地理位置、SIM 或 VPN 判断准确。`RegionSignalKit.evaluate` 可接收自定义 `Observations` 便于测试，但输入不构成可信证明。

## 测试和发布

运行 `swift test`；运行 `pod lib lint RegionSignalKit.podspec --allow-warnings` 检查本地 pod。发布前修改 podspec 中 homepage、source、author 为实际值，检查 Pod 名称，推送公开仓库和 `0.1.0` 标签，再用 `pod spec lint` 检查远程来源并自行执行 `pod trunk push`。发布成功后可按上面的方式接入。

## 命名与混淆

库、模块和公开入口已统一命名为 `RegionSignalKit`。内部对部分判断常量和隧道接口前缀做了可逆字节混淆，并简化部分私有符号名称。混淆只能降低静态查看时的可读性，不是加密，无法阻止反编译或篡改；公开 API、服务端字段、检查结果及说明仍可读。不要把密钥放在客户端，也不要依赖混淆作为服务端授权或安全保障。
