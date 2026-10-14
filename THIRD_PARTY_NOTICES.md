# 素材与第三方许可

**简体中文** · [English](THIRD_PARTY_NOTICES.en.md)

本项目原创代码和文档采用 [MIT](LICENSE)。第三方内容保留原许可，不能将仓库的 MIT 许可解释为替代它们的许可。

## 历史 CPU 模型实验

`BabySignal/Models/YAMNet.mlpackage` 为 Yehor 发布的 Google YAMNet Core ML 转换版本，固定版本 `9681162a6618cceb548ee2a94e83bcfb3a141066`。

- 上游模型：[Google YAMNet](https://github.com/tensorflow/models/tree/master/research/audioset/yamnet)
- 转换作者与模型卡：[Yehor/YAMNet-CoreML](https://huggingface.co/Yehor/YAMNet-CoreML)
- 许可：Apache-2.0，完整许可见 [LICENSE-YAMNet.txt](BabySignal/Models/LICENSE-YAMNet.txt)
- 文件哈希：[docs/yamnet-assets.json](docs/yamnet-assets.json)

这些模型与对应实验代码不参与当前 App 的构建。若用于自己的派生版本，请保留上游来源、许可和修改说明，并独立验证预处理与识别表现。原生预处理及推理适配代码由本项目实现，不构成经过上游作者认证的转换验证。

## 图片

App 内三张使用图解及 `docs/images` 故事插画使用 Codex 内置 image_gen 生成。故事人物均为虚构，不能作为真实当事人的照片或证据。项目将生成图片按 MIT 许可条件提供，但不宣称 AI 生成图片在所有地区均具有可主张的著作权；图片不代表任何个人、品牌或平台背书。

提示词见 [illustration-prompts.json](docs/illustration-prompts.json) 与 [story-image-prompt.json](docs/story-image-prompt.json)。原始视频及评论截图不在仓库中，也不受本项目许可覆盖。

## 测试音频

仓库不分发测试哭声音频、宝宝录音或其他家庭音频。历史验证仅使用了外部样本。贡献者应使用有权使用的样本，不将可识别儿童或家庭的录音提交到公开 Issue 或仓库。
