# AGENTS.md

## 项目定位

本项目是基于 HarmonyOS ArkTS 的智能语音助手系统。目标不是只做静态 UI，而是完成一条可验证的语音交互链路：

语音采集 -> 语音转文字 -> 语义理解 -> 指令执行 -> 语音反馈。

课程/项目硬性要求：

- 使用 ArkTS 或仓颉；本仓库当前采用 ArkTS。
- 使用 LibriSpeech 数据集，资源来源为 OpenSLR SLR12。
- 基于科大讯飞语音识别 API 和 Transformer 模型开发。
- 语音转写准确率不低于 93%。
- 系统响应时间不超过 2 秒。

重要事实：LibriSpeech 是英文朗读语音数据集。评测链路不得把英文 LibriSpeech 与中文普通话识别配置混用后宣称达到准确率指标。若保留中文语音交互，应明确区分：

- 实时中文交互链路：面向用户语音助手体验。
- LibriSpeech 英文评测链路：面向 93% 准确率和 2 秒响应时间验收。

## 沟通与执行规则

- 默认中文沟通；代码、命令、类名、变量名使用英文。
- 结论先行，先说能不能做、风险在哪里，再给实现细节。
- 不因为现有代码已经这样写就继续照搬；先回到项目要求判断是否合理。
- 大改动先给方案，确认后再动手。
- 不删除文件、目录、构建产物、数据集、git 历史，除非 Champ 明确确认。
- 不修改 `.env`、密钥、token、CI/CD、系统配置，除非 Champ 明确确认。
- 完成一个小单元的完整改动并完成可执行验证后，自动创建 git commit；验证受本机环境阻塞时需在提交说明中注明。涉及红线操作、验证失败、用户明确要求不提交时，不自动 commit。
- 不推送、不发布，除非 Champ 明确要求。

## 目录结构约定

- `AGENTS.md`：项目规则。改实践前先改这里。
- `docs/`：项目介绍、分工、协作说明。
- `entry/src/main/ets/pages/`：ArkUI 页面，只做展示、交互状态和事件转发。
- `entry/src/main/ets/components/`：可复用 ArkUI 组件；页面超过 400 行优先拆组件。
- `entry/src/main/ets/viewmodel/`：页面编排层，串联采集、识别、理解、执行、反馈、统计。
- `entry/src/main/ets/core/`：核心业务能力，新增代码优先放入 `audio/`、`asr/`、`nlu/`、`command/`、`feedback/`、`evaluation/` 子目录。
- `entry/src/main/ets/model/`：领域模型和 Transformer 实验模型。
- `entry/src/main/ets/utils/`：数据集、音频、性能等通用工具。
- `entry/src/main/ets/config/`：只放非敏感配置和读取逻辑。
- `entry/src/main/resources/rawfile/`：演示资源和小规模数据集。新增、移动、裁剪 LibriSpeech 前必须说明原因并确认。
- `entry/src/test/`、`entry/src/ohosTest/`：单元测试和设备测试。模板测试不能算有效覆盖。

## 模块边界

- 语音采集：使用明确状态机 `idle`、`recording`、`stopping`、`recognizing`、`completed`、`failed`；设备异常必须返回 UI 可理解错误。
- ASR：科大讯飞 API 调用必须封装在 `core/asr`，页面和 ViewModel 不拼签名；签名失败必须失败返回；日志不得输出密钥、完整 Authorization 或大块音频。
- NLU：意图名使用稳定枚举或常量；规则、实体抽取、置信度策略集中维护；新增意图必须补样例和测试。
- Command：模拟能力必须用 `mock`/`simulated` 或结果状态标明；每个执行结果都包含成功/失败状态。
- Feedback：未接入 TTS 时必须称为文字反馈或模拟语音反馈。
- Transformer：UI 或文档宣称“基于 Transformer”时，必须真实参与主流程，或明确标为实验模块并提供可运行入口和评测方式。
- Evaluation：LibriSpeech 保持 `speaker/chapter/audio + transcript`；准确率基于 `.trans.txt`；FLAC 必须真实解码；评测结果至少记录样本、基准文本、识别文本、WER/相似度、响应时间和失败原因。

## 敏感配置规则

- 不得在 `.ets`、`.ts`、`.json5`、测试、日志中硬编码真实密钥。
- `entry/src/main/ets/config/` 只能存非敏感默认值、类型定义、读取逻辑。
- 本地密钥放 `.env` 或系统安全存储；`.env` 不提交、不展示、不写入日志。
- `.env.example` 只保存变量名和占位符，不能保存真实 `appId`、`apiKey`、`apiSecret`。
- 一旦密钥进入源码，按已泄露处理：先轮换，再改读取方式。
- 任何需要修改 `.env`、新增密钥、替换 token 的操作，必须先问 Champ。

## 代码风格

- 优先小函数、清晰类型、明确命名。
- 避免长页面文件继续膨胀；页面超过 400 行时优先拆组件或 Builder。
- 避免魔法数字；如录音时长、采样率、超时时间、准确率阈值、响应时间阈值都要抽常量。
- 不为了“跑起来”吞异常、注释报错代码或加绕过逻辑。
- 日志要能定位问题，但不能输出敏感信息和大量音频内容。
- 新增能力先补接口边界，再接 UI。

## ArkTS 编译约束

项目使用 ArkTS 严格编译，新增或修改 `.ets` 文件时必须避开以下 TypeScript 写法，否则 `UnitTestArkTS` 会失败：

- 不使用正则字面量 `/.../`，统一写成 `new RegExp('...', flags)`，反斜杠要按字符串规则转义。
- 不使用 `any`、`unknown` 类型。错误对象按具体类型处理，例如 `BusinessError`，或定义明确的接口类型。
- 返回类型不包含 `undefined` 的函数必须所有分支显式 `return` 或 `throw`。`catch` 中调用会抛错的 helper 后，也要用 `return await helper(...)` 等方式让编译器确认路径结束。
- 不使用对象展开 `{ ...obj }`；需要拷贝对象时手写字段映射，避免 ArkTS `arkts-no-spread`。
- 不使用数组/迭代器解构声明，例如 `const [key, value] = entry`；改成 `const key = entry[0]`、`const value = entry[1]`。
- 不使用数组展开 `[...values]`；复制数组用 `values.slice(0)`。

## 测试要求

核心逻辑必须有测试：

- `SemanticUnderstanding`：意图识别、实体抽取、未知指令、置信度。
- `CommandExecutor`：每类指令成功/失败结果。
- `SpeechRecognizer` / ASR service：请求构造、响应解析、错误码处理。真实 API 调用要 mock。
- `DatasetLoader`：转录文本解析、样本匹配、空数据集、异常路径。
- `AudioUtils`：音频格式判断、解码失败、归一化边界。
- `PerformanceMonitor`：平均响应时间、准确率、阈值判断。

模板测试如 `abc` 包含 `b` 不算项目测试覆盖。

## 验证流程

每次功能改动后至少执行：

1. ArkTS 语法/类型检查。
2. 单元测试。
3. HAP 构建。
4. 真机或模拟器手动验证核心链路。

当前仓库没有 `hvigorw` 包装脚本时，优先使用 DevEco Studio 执行：

- Sync Project。
- Build Hap(s)/APP(s)。
- Run unit tests。
- 真机/模拟器运行 `entry`。

本机命令行执行 hvigor/UnitTestBuild 时，可按个人机器的 DevEco Studio SDK 安装位置临时指定 `DEVECO_SDK_HOME`，不要修改系统环境变量，也不要把个人绝对路径写成项目通用配置：

```bash
DEVECO_SDK_HOME=<local-deveco-sdk-root> \
<local-deveco-node> \
<local-hvigorw.js> \
--sync -p product=default --analyze=normal --parallel --incremental --daemon
```

注意：`DEVECO_SDK_HOME` 应指向 SDK 根目录，而不是某个具体版本或 `default` 子目录。不同成员的 SDK 路径可能不同，路径只作为本机验证参数使用。构建、测试和 HAP 打包允许使用较长超时；超过 2-5 分钟仍无输出时再判断是否卡住并停止 daemon。如果临时 SDK 路径仍报 `SDK component missing` 或 `DEVECO_SDK_HOME` 无效，不继续修改系统 SDK 配置；记录验证受阻原因，并由对应开发者在 DevEco Studio 内手动运行对应测试。

如果本地安装了 CLI 工具，可使用项目确认过的等价命令。新增 CLI 验证命令前，先把命令写回本文件。

手动验收最少覆盖：

- 首次启动权限申请。
- 开始录音 -> 停止录音 -> 返回识别文本。
- 未授权麦克风时的错误提示。
- 网络/API 失败时的错误提示。
- 响应时间展示与统计合理。

## 性能与验收指标

- 语音转写准确率目标：不低于 93%。
- 系统响应时间目标：不超过 2 秒。
- UI 展示的准确率和响应时间必须来自真实统计，不允许写死。
- 不得用 `command.confidence * 100` 冒充语音转写准确率。
- 评测样本数太少时必须标注，不得用 1-10 条样本代表完整指标。

## 资源与包体规则

- `entry/build/`、`.hvigor/`、`.preview/`、`oh_modules/` 属于生成或依赖目录，不作为业务代码依据。
- LibriSpeech 原始资源体积大，不进 git；本地按 `entry/src/main/resources/rawfile/dev-clean/LibriSpeech/` 放置。
- `.gitignore` 必须忽略 LibriSpeech 数据集目录，避免误提交大文件。
- 新增完整训练集前必须确认包体和设备存储影响。
- 如果只需要演示，优先保留小规模评测子集，并记录抽样规则。
- 不得直接删除现有数据集；需要清理时先列出路径、体积、影响，确认后再做。

## 交付前检查

交付前必须确认：

- 没有真实密钥进入源码。
- 项目能构建。
- 核心测试通过。
- 准确率和响应时间来自真实统计，口径可解释。
- UI 和文档不夸大未实现能力。
- 大体积资源、生成目录、密钥不会误提交。
