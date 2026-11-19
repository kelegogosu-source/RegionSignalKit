# RegionSignalKit

iOS 15+ / Swift 5 检查库。提供不联网的设备检查，以及可选的 HTTPS 公网 IP 国家查询；每项返回通过、拒绝或无法确认。

## 安装

```ruby
pod 'RegionSignalKit', '~> 0.3.0'
```

执行 `pod install` 并使用 `.xcworkspace` 打开项目。

## 查询 IP 国家

```swift
import RegionSignalKit

RegionSignalKit.checkWithIP { report in
    for item in report.results {
        print(item.check.rawValue, item.state.rawValue, item.detail)
    }
    DispatchQueue.main.async {
        if report.allowed {
            // 检查通过
        } else {
            // 拒绝或无法确认
        }
    }
}
```

该方法向第三方 `https://ipwho.is/` 发起 HTTPS 请求；对方会看到设备请求的出口 IP。服务根据出口 IP 返回国家代码；库拒绝美国 IP，也比较设备地区与 IP 国家。查询失败、超时、格式错误、被限流或国家码无效时返回 `unknown`，默认拒绝。回调不保证在主线程。服务免费额度及可用性取决于服务商，IP 归属数据可能不准确，VPN、代理、IPv6、Private Relay 等会改变或隐藏实际出口。

## 本机检查

`RegionSignalKit.check(policy: .deviceSettings)` 是同步、不联网的地区和首选语言检查。`RegionSignalKit.check()` 不联网且默认启用全部项目，因此 IP 检查为 `unknown`。

`Policy()` 默认启用全部检查并拒绝未知结果。**即使 IP 查询成功，SIM 检查始终无法确认，默认策略仍会阻止所有设备。** 如果业务明确接受限制，可以设置 `policy.enabledChecks` 仅启用可确认项目；设置 `unknownIsRejected = false` 会允许所有启用项目中的未知结果，不代表这些项目已通过。

## 各项限制

- `ipCountry`：`checkWithIP` 查询的 IP 国家为美国时拒绝。
- `regionMatchesIP`：设备地区与 IP 国家不同时拒绝；旅行或 IP 数据不准确可能导致误判。
- `deviceRegion`：设备地区设置为美国时拒绝，不是 GPS 定位。
- `deviceLanguage`：首选语言是英语时拒绝。
- `vpn`：发现隧道接口时拒绝；这只是可能误报或漏报的启发式，未发现时返回 `unknown`。
- `simPresent`、`physicalSIM`：iOS 无通用可靠公开接口判断有无 SIM 或区分实体卡和 eSIM，始终返回 `unknown`。

所有客户端检查都可能被篡改，不能代替可信服务端授权。

## 版本与验证

0.3.0 新增异步 `checkWithIP`；现有 `check` 仍然不联网。测试运行 `swift test`，本地 Pod 检查运行 `pod lib lint RegionSignalKit.podspec --allow-warnings`。内部常量混淆只是降低可读性，不是加密。
