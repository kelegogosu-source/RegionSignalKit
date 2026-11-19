# RegionSignalKit

iOS 15+ / Swift 5 本机检查库。0.2.0 版本无需接口地址，不会发起网络请求；可以检查设备地区、首选语言和本机隧道接口迹象。每项返回通过、拒绝或无法确认，由接入方根据结果决定是否拦截。

## 安装

```ruby
platform :ios, '15.0'

target '你的项目名称' do
  use_frameworks!
  pod 'RegionSignalKit', '~> 0.2.0'
end
```

执行 `pod install` 并使用 `.xcworkspace` 打开项目。

## 在手机上检查

```swift
import UIKit
import RegionSignalKit

final class ViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // deviceSettings 只启用设备地区、首选语言两项。
        let report = RegionSignalKit.check(policy: .deviceSettings)
        let details = report.results.map { item in
            "\(item.check.rawValue): \(item.state.rawValue)\n\(item.detail)"
        }.joined(separator: "\n\n")

        let alert = UIAlertController(
            title: report.allowed ? "检查通过" : "检查未通过",
            message: details,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
```

`check` 是同步方法，不需要 URL、回调、网络或服务端。`passed` 为通过、`rejected` 为拒绝、`unknown` 为无法确认。

## 检查项目与限制

- `deviceRegion`：系统地区为美国（`US`）时拒绝。它是用户可修改的设置，并不是 GPS 位置。
- `deviceLanguage`：首选语言为英语（`en`，包括 `en-US`、`en-GB`）时拒绝。只检查首选语言，不检查所有备选语言。
- `vpn`：发现名称类似隧道的活动网络接口时拒绝；这种启发式可能误报或漏报。未发现时返回 `unknown`，不能证明没有使用 VPN。
- `ipCountry`、`regionMatchesIP`：无离线 IP 归属数据，因此返回 `unknown`。库不会访问网站，也不会自动查询 IP 国家。
- `simPresent`、`physicalSIM`：iOS 不提供通用可靠的公开接口来确认是否有卡或区分实体卡与 eSIM，因此返回 `unknown`。

设备和网络判断不是可信的身份或安全证明，可能被用户修改或绕过。

## 策略

`Policy()` 默认启用所有检查，且未知时拒绝。由于 IP、SIM 等项无法本机确定，默认策略的 `report.allowed` 始终为 `false`。可使用 `.deviceSettings` 只启用地区和语言，或按需求自行设置：

```swift
var policy = Policy.deviceSettings
policy.enabledChecks.insert(.vpn)
let report = RegionSignalKit.check(policy: policy)
```

以上例子中，如果发现隧道迹象会拒绝；没有发现也不能确定 VPN 状态，因此仍返回 `unknown` 并默认拒绝。设置 `policy.unknownIsRejected = false` 可允许未知项，但会影响所有启用的检查，**不表示这些检查已通过**。明确拒绝的项目仍会拒绝。

## 从 0.1.x 升级

0.2.0 为纯本机版本，移除了 `RegionSignalKitClient`、`NetworkSignals` 和 HTTPS 接口支持，改用同步的 `RegionSignalKit.check(policy:)`。如果原先使用服务端判断 IP 国家或 VPN，升级后这些数据不会自动获取，需由应用自行决定如何处理；不可把未知当作已通过。

## 测试与混淆

运行 `swift test`；运行 `pod lib lint RegionSignalKit.podspec --allow-warnings` 验证本地 Pod。部分内部常量和私有符号做了轻量可逆混淆，仅降低静态查看时的可读性，不是加密，不能阻止反编译或篡改。
