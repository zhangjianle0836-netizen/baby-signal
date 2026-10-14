# 宝宝信号界面更新

## 视觉方向

奶油米色页面、象牙白卡片、暖陶色主操作、柔和棕灰色说明文字。用图片配合短句帮助理解操作，不依赖声音或单独的颜色表达状态。白字主按钮的计算对比度约为 6.5:1。

## 插画资产

生成方式：内置 `image_gen`。完整生成和编辑提示词保存在 [illustration-prompts.json](illustration-prompts.json)。最终使用资产：

- [手机摆放](../BabySignal/Assets.xcassets/GuidePhone.imageset/illustration.png)：手机在婴儿床外。
- [手表佩戴](../BabySignal/Assets.xcassets/GuideWatch.imageset/illustration.png)：展示佩戴与触感提醒。
- [查看宝宝](../BabySignal/Assets.xcassets/GuideCare.imageset/illustration.png)：妈妈抱起宝宝查看。

图片是操作示意，不是实时画面，不表达宝宝健康状况或已确认安全。图示之外仍保留可读文字说明。

## 已检查与待验证

已检查 iPhone 14 Pro 的浅色首页、深色及较大辅助字体下的首页显示。原生字体缩放、按钮标签和提示已实现，但未完成全部页面的 VoiceOver 操作和所有辅助字体尺寸的检查。

更新后重新启动 App，保持未开始监测，不播放测试哭声。此前闹钟停止后自动恢复的代码已通过逻辑检查；两轮连续的锁屏真机验证被暂停，仍待继续，不以这次视觉更新代替行为验证。

## 开发预览

Debug 启动参数 `--ui-dark` 可预览深色，`--ui-large-text` 可预览 accessibility3 字体；无参数时遵循设备设置，不修改系统设置。Release 不启用这些覆盖。
