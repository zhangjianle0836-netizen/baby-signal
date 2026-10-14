# 中英文 / Chinese and English

## 简体中文

产品使用同一份共享 `Localizable.strings`，包含简体中文和英文 202 个键，App 和 Live Activity 扩展都嵌入。权限提示与桌面名称使用各 target 的 `InfoPlist.strings`；App Intent 和 AlarmKit 的静态文案通过原生 `LocalizedStringResource` 查找相同资源。

语言跟随系统／应用设置；默认开发语言为英文。没有新增运行时依赖，也不为了换语言重写提醒历史或改变检测规则。固定记录说明按当前语言显示；系统错误的原始描述可能保留其生成时语言。已安排的闹钟可能保留创建时文本。

资源检查：`python3 scripts/check_localizations.py` 验证键集合、占位符和 Swift 文案覆盖。`scripts/verify.sh tests` 验证运行时查找、格式化及历史说明转换。当前 72 项逻辑检查和 5 个真实静音分析窗口通过；双 target 真机签名构建通过。完整权限弹窗、已安排闹钟、手表语言、VoiceOver 和所有大字体页面仍需实际复核。

项目介绍、故事、技术思路、隐私、贡献、第三方素材说明和主要实验资料均提供互链的中英文版本。锁屏识别失败等限制在两种语言中一致说明。

## English

The app and Live Activity extension embed a shared `Localizable.strings` table with 202 Simplified Chinese/English keys. Each target has its own localized `InfoPlist.strings` for names and permissions. Native App Intent and AlarmKit string resources use the same shared translation keys.

Language follows system/app settings; English is the development fallback. No runtime dependency was added. Localization does not rewrite history or change detection rules. Fixed historical descriptions are translated for display; original system error text and already scheduled alarms may retain their creation language.

Run `python3 scripts/check_localizations.py` for key, placeholder and source coverage. Core tests check native lookup, formatting and historical-description translation. 72 checks and five real silence-analysis windows passed; both device targets built successfully. Complete permission, existing-alarm, Watch-language, VoiceOver and large-text coverage remain manual test items.

Public introductory, story, design, privacy, contribution and experiment documents link between Chinese and English. Both versions retain the same unresolved locked-screen classification limitation.
