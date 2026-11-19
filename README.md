# RegionSignalKit

iOS 15+ / Swift 5 设备与 IP 国家检查库。`check` 不联网；`checkWithIP` 使用 Cloudflare 的 HTTPS 诊断地址查询出口 IP 的国家。库不使用 IPWhois。

## 安装

```ruby
pod 'RegionSignalKit', '~> 0.4.0'
```

执行 `pod install` 后使用 `.xcworkspace` 打开工程。

## 检查 IP 国家

```swift
import RegionSignalKit

RegionSignalKit.checkWithIP { report in
    for result in report.results {
        print(result.check.rawValue, result.state.rawValue, result.detail)
    }
    DispatchQueue.main.async {
        if report.allowed { /* 允许 */ }
        else { /* 拒绝或无法确认 */ }
    }
}
```

该方法请求 `https://www.cloudflare.com/cdn-cgi/trace` 并解析 `loc` 国家码，不需要自己的服务器。Cloudflare 会收到请求的出口 IP；库不会记录或返回接口响应中的 IP。请求失败、超时、格式变化、国家码无效或未知时，IP 国家和地区一致性结果均为 `unknown`。回调在 URLSession 回调线程，更新 UI 时切换主线程。

此地址是 Cloudflare 的诊断接口，不是保证格式或可用性的国家查询 API，可能变化或被限流。IP 国家是估计值；VPN、代理、Private Relay 或不同网络路由可能影响出口。请根据实际使用处理隐私说明。

## 检查项及默认策略

- `ipCountry`：出口 IP 国家为 `US` 时拒绝。
- `regionMatchesIP`：设备地区与 IP 国家不同时拒绝。
- `deviceRegion`：系统地区为美国时拒绝。
- `deviceLanguage`：首选语言为英语时拒绝。
- `vpn`：发现疑似隧道接口时拒绝；未发现时返回 `unknown`，可能误报或漏报。
- `simPresent`、`physicalSIM`：iOS 无通用可靠公开接口判断有无 SIM 或区分实体卡与 eSIM，返回 `unknown`。

`Policy()` 启用全部检查且未知时拒绝。**即便 IP 查询成功，SIM 检查仍无法确认，因此默认策略会拒绝所有设备。** `Policy.deviceSettings` 只启用设备地区和首选语言；可通过 `enabledChecks` 自定义检查。设置 `unknownIsRejected = false` 会影响所有启用项，不代表未知项已通过。客户端判断可能被篡改，不能代替可信服务端授权。

## 版本与验证

0.4.0 将 `checkWithIP` 的查询服务从 IPWhois 改为 Cloudflare 诊断地址；`check()` 仍保持离线。运行 `swift test` 检查规则，`pod lib lint RegionSignalKit.podspec --allow-warnings` 验证 Pod。内部常量混淆仅降低可读性，不是加密。
