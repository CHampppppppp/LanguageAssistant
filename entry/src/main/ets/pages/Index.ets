// C:/Users/pzl/PycharmProjects/语音助手/entry/src/main/ets/pages/Index.ets
import { VoiceAssistantViewModel } from '../viewmodel/VoiceAssistantViewModel';

@Entry
@Component
struct Index {
  @State viewModel: VoiceAssistantViewModel = new VoiceAssistantViewModel();
  @State recognitionText: string = '点击麦克风开始语音识别';
  @State commandResult: string = '';
  @State feedbackText: string = '';
  @State isRecording: boolean = false;
  @State accuracy: number = 0;
  @State responseTime: number = 0;
  @State datasetInfo: string = '';
  @State isProcessing: boolean = false;
  @State pulseAnimation: number = 0;
  @State rawTranscriptText: string = '';
  @State isAnimating: boolean = false;
  @State audioLevels: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  @State currentAudioLevel: number = 0;

  aboutToAppear(): void {
    // 获取当前页面的 Context 并传递给 ViewModel
    const context: Context = this.getUIContext().getHostContext() as Context;
    this.viewModel.setContext(context);

    this.viewModel.init();
    this.loadDatasetInfo();

    this.viewModel.setAudioLevelCallback((level: number) => {
      this.currentAudioLevel = level;
      this.updateWaveformFromAudioLevel(level);
    });
  }

  aboutToDisappear(): void {
    this.viewModel.destroy();
  }

  loadDatasetInfo(): void {
    this.datasetInfo = 'LibriSpeech dev-clean 数据集已加载';
  }

  updateWaveformFromAudioLevel(level: number): void {
    const newLevels: number[] = [];
    const baseHeight: number = Math.max(level * 0.4, 2);

    for (let i: number = 0; i < 9; i++) {
      const variation: number = (Math.random() - 0.5) * level * 0.3;
      const height: number = Math.max(baseHeight + variation, 2);
      newLevels.push(Math.min(height, 40));
    }

    this.audioLevels = newLevels;
  }

  async startRecognition(): Promise<void> {
    this.isRecording = true;
    this.isAnimating = true;
    this.recognitionText = '正在录音...';
    this.commandResult = '';
    this.feedbackText = '';
    this.rawTranscriptText = '';
    this.audioLevels = [0, 0, 0, 0, 0, 0, 0, 0, 0];

    try {
      const startTime: number = Date.now();
      const result = await this.viewModel.processVoiceCommand();
      this.responseTime = Date.now() - startTime;

      this.recognitionText = result.recognizedText || '未识别到语音内容';
      this.rawTranscriptText = result.recognizedText || '';
      this.commandResult = result.commandResult;
      this.feedbackText = result.feedback;
      this.accuracy = result.accuracy;
    } catch (error) {
      this.recognitionText = '识别失败，请重试';
      this.rawTranscriptText = '识别失败';
      console.error('语音识别错误:', error);
    } finally {
      this.isRecording = false;
      this.isAnimating = false;
      this.audioLevels = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    }
  }

  async stopRecording(): Promise<void> {
    this.isRecording = false;
    this.isAnimating = false;
    this.recognitionText = ' 正在处理录音...';
    this.rawTranscriptText = '正在识别语音...';

    try {
      const result = await this.viewModel.stopAndProcessRecording();

      this.recognitionText = result.recognizedText || '未识别到语音内容';
      this.rawTranscriptText = result.recognizedText || '';
      this.commandResult = result.commandResult;
      this.feedbackText = result.feedback;
      this.accuracy = result.accuracy;
    } catch (error) {
      this.recognitionText = '识别失败，请重试';
      this.rawTranscriptText = '识别失败';
      console.error('语音识别错误:', error);
    }

    console.info('用户手动停止录音');
  }

  async testWithDataset(): Promise<void> {
    this.recognitionText = ' 正在使用数据集测试...';
    try {
      const result = await this.viewModel.testWithDataset();
      this.recognitionText = `✅ 测试完成 - 准确率: ${result.accuracy}%`;
      this.commandResult = ` 处理样本数: ${result.sampleCount}`;
      this.responseTime = result.avgResponseTime;
      this.accuracy = result.accuracy;
    } catch (error) {
      this.recognitionText = ' 数据集测试失败';
      console.error('数据集测试错误:', error);
    }
  }

  build() {
    Scroll() {
      Column() {
        this.buildHeader()
        this.buildStatusCard()
        this.buildTranscriptCard()
        this.buildRecognitionCard()
        this.buildCommandCard()
        this.buildFeedbackCard()
        this.buildButtons()
        this.buildRecordingIndicator()
      }
      .width('100%')
      .padding({ top: 10, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
  }

  @Builder
  buildHeader() {
    Column() {
      Row() {
        Text('️')
          .fontSize(32)

        Column() {
          Text('智能语音助手')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E')

          Text('基于 Transformer + 科大讯飞 API')
            .fontSize(12)
            .fontColor('#6C757D')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 10 })
    }
    .width('100%')
    .linearGradient({
      direction: GradientDirection.Right,
      colors: [['#667EEA', 0], ['#764BA2', 1]]
    })
    .borderRadius({ bottomLeft: 20, bottomRight: 20 })
    .shadow({
      radius: 10,
      color: '#00000020',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  buildStatusCard() {
    Row() {
      this.buildStatusItem('', '数据集', this.datasetInfo, '#4CAF50')

      Divider()
        .vertical(true)
        .height(40)
        .color('#E0E0E0')
        .strokeWidth(1)

      this.buildStatusItem('🎯', '准确率', `${this.accuracy}%`, this.accuracy >= 93 ? '#4CAF50' : '#FF5722')

      Divider()
        .vertical(true)
        .height(40)
        .color('#E0E0E0')
        .strokeWidth(1)

      this.buildStatusItem('⚡', '响应时间', `${this.responseTime}ms`, this.responseTime <= 2000 ? '#4CAF50' : '#FF5722')
    }
    .width('90%')
    .height(80)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .margin({ top: 20, bottom: 15 })
    .justifyContent(FlexAlign.SpaceEvenly)
    .shadow({
      radius: 8,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  buildStatusItem(icon: string, label: string, value: string, color: string) {
    Column() {
      Text(icon)
        .fontSize(20)

      Text(label)
        .fontSize(11)
        .fontColor('#9E9E9E')
        .margin({ top: 4 })

      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildTranscriptCard() {
    Column() {
      Row() {
        Text('📄')
          .fontSize(18)

        Text('语音转文字原始结果')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
          .margin({ left: 8 })

        Blank()

        if (this.rawTranscriptText) {
          Text('📋')
            .fontSize(16)
        }
      }
      .width('100%')
      .margin({ bottom: 12 })

      TextArea({ text: this.rawTranscriptText, placeholder: '语音识别的文字将显示在这里...' })
        .width('100%')
        .height(100)
        .padding(12)
        .backgroundColor('#F0F4FF')
        .borderRadius(12)
        .border({ width: 1, color: '#C5CAE9' })
        .fontSize(15)
        .fontColor('#333333')
        .textAlign(TextAlign.Start)
    }
    .width('90%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .margin({ bottom: 15 })
    .shadow({
      radius: 8,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  buildRecognitionCard() {
    Column() {
      Row() {
        Text('📝')
          .fontSize(18)

        Text('识别结果')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
          .margin({ left: 8 })

        Blank()

        if (this.isProcessing) {
          Text('✅')
            .fontSize(16)
        }
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text(this.recognitionText)
        .fontSize(15)
        .fontColor('#333333')
        .width('100%')
        .height(60)
        .padding(16)
        .backgroundColor('#F8F9FA')
        .borderRadius(12)
        .border({ width: 1, color: '#E8E8E8' })
        .textAlign(TextAlign.Start)
        .lineHeight(24)
    }
    .width('90%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .margin({ bottom: 15 })
    .shadow({
      radius: 8,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  buildCommandCard() {
    Column() {
      Row() {
        Text('⚙️')
          .fontSize(18)

        Text('指令执行结果')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text(this.commandResult)
        .fontSize(14)
        .fontColor('#555555')
        .width('100%')
        .height(60)
        .padding(14)
        .backgroundColor('#FFF8E1')
        .borderRadius(12)
        .border({ width: 1, color: '#FFE082' })
        .textAlign(TextAlign.Start)
    }
    .width('90%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .margin({ bottom: 15 })
    .shadow({
      radius: 8,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  buildFeedbackCard() {
    Column() {
      Row() {
        Text('💬')
          .fontSize(18)

        Text('语音反馈')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text(this.feedbackText)
        .fontSize(14)
        .fontColor('#2E7D32')
        .width('100%')
        .height(60)
        .padding(14)
        .backgroundColor('#E8F5E9')
        .borderRadius(12)
        .border({ width: 1, color: '#A5D6A7' })
        .textAlign(TextAlign.Start)
    }
    .width('90%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .margin({ bottom: 20 })
    .shadow({
      radius: 8,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  buildButtons() {
    Row() {
      Button() {
        Row() {
          Text(this.isRecording ? '⏹️' : '🎤')
            .fontSize(20)

          Text(this.isRecording ? '停止录音' : '开始识别')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 8 })
        }
      }
      .width('45%')
      .height(52)
      .backgroundColor(this.isRecording ? '#FF5722' : '#667EEA')
      .borderRadius(26)
      .onClick(() => {
        if (this.isRecording) {
          this.stopRecording();
        } else {
          this.startRecognition();
        }
      })
      .shadow({
        radius: 12,
        color: this.isRecording ? '#FF572240' : '#667EEA40',
        offsetX: 0,
        offsetY: 4
      })

      Button() {
        Row() {
          Text('')
            .fontSize(20)

          Text('数据集测试')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 8 })
        }
      }
      .width('45%')
      .height(52)
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [['#FF6B35', 0], ['#FF8E53', 1]]
      })
      .borderRadius(26)
      .onClick(() => {
        this.testWithDataset();
      })
      .shadow({
        radius: 12,
        color: '#FF6B3540',
        offsetX: 0,
        offsetY: 4
      })
    }
    .width('90%')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ bottom: 20 })
  }

  @Builder
  buildRecordingIndicator() {
    if (this.isRecording) {
      Column() {
        Row() {
          Text('●')
            .fontSize(12)
            .fontColor('#FF0000')
            .animation({
              duration: 800,
              iterations: -1,
              curve: Curve.EaseInOut
            })

          Text(` 正在录音 (音量: ${Math.round(this.currentAudioLevel)}%)`)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FF0000')
        }

        Row() {
          ForEach(this.audioLevels, (height: number) => {
            Column()
              .width(4)
              .height(height)
              .backgroundColor(this.currentAudioLevel > 5 ? '#667EEA' : '#CCCCCC')
              .margin({ left: 3 })
              .borderRadius(2)
              .animation({
                duration: 100,
                curve: Curve.EaseOut
              })
          })
        }
        .height(40)
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 10 })
        .justifyContent(FlexAlign.Center)

        if (this.currentAudioLevel === 0 && this.isRecording) {
          Text('️ 未检测到音频输入，请检查麦克风权限')
            .fontSize(12)
            .fontColor('#FF5722')
            .margin({ top: 8 })
        }
      }
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .backgroundColor('#FFEBEE')
      .borderRadius(20)
      .border({ width: 1, color: '#FFCDD2' })
      .margin({ top: 10 })
    }
  }
}