# Proxifier Switch 技术方案

当前使用场景：

- 外网场景：连接手机热点，手动打开 ClashX Pro，用于访问外网。
- 公司内网场景：连接公司 Wi-Fi，需要使用 Proxifier，并且 Proxifier 默认配置已经是公司内网代理规则。
- 公司内网规则已经在 Proxifier 里配置好，不需要本工具切换 Proxifier profile。

目标是开发一个 macOS 菜单栏应用 **Proxifier Switch**：

- 根据当前 Wi-Fi 自动打开或关闭 Proxifier。
- 命中特定 Wi-Fi 时自动打开 Proxifier。
- 离开目标 Wi-Fi 时自动关闭 Proxifier。
- 用户可以在菜单栏暂停自动控制，方便在目标 Wi-Fi 外自行从 Applications/Finder 打开 Proxifier 查看或修改配置。
- 初始版本需要包含配置面板。
- 不切换 macOS 网络位置。
- 不切换 Proxifier profile。
