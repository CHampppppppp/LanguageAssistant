import { VoiceAssistantViewModel } from '../viewmodel/VoiceAssistantViewModel';
import { StatusPanel } from '../components/StatusPanel';
import { InfoPanel } from '../components/InfoPanel';
import { ControlButtons } from '../components/ControlButtons';
import { RecordingIndicator } from '../components/RecordingIndicator';
import { AssistantFlowState, getAssistantFlowLabel, isAssistantFlowBusy } from '../viewmodel/AssistantFlowState';

@Entry
@Component
struct Index {
  @State viewModel: VoiceAssistantViewModel = new VoiceAssistantViewModel();
  @State recognitionText: string = '点击麦克风开始语音识别';
  @State commandResult: string = '';
  @State feedbackText: string = '';
  @State flowState: AssistantFlowState = AssistantFlowState.IDLE;
  @State evaluationAccuracy: number = 0;
  @State responseTime: number = 0;
  @State datasetInfo: string = 'LibriSpeech 英文评测资源';
  @State rawTranscriptText: string = '';
  @State audioLevels: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  @State currentAudioLevel: number = 0;

  aboutToAppear(): void {
    const context: Context = this.getUIContext().getHostContext() as Context;
    this.viewModel.setContext(context);
    this.viewModel.init();
    this.viewModel.setAudioLevelCallback((level: number) => {
      this.currentAudioLevel = level;
      this.updateWaveformFromAudioLevel(level);
    });
    this.viewModel.setFlowStateCallback((state: AssistantFlowState) => {
      this.flowState = state;
    });
  }

  aboutToDisappear(): void {
    this.viewModel.destroy();
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
    this.flowState = AssistantFlowState.RECORDING;
    this.recognitionText = '正在录音...';
    this.commandResult = '';
    this.feedbackText = '';
    this.rawTranscriptText = '';
    this.audioLevels = [0, 0, 0, 0, 0, 0, 0, 0, 0];

    try {
      await this.viewModel.startRecording();
    } catch (error) {
      this.flowState = AssistantFlowState.FAILED;
      this.recognitionText = '录音启动失败，请检查麦克风权限';
      this.rawTranscriptText = '录音启动失败';
      console.error('录音启动错误:', error);
    }
  }

  async stopRecording(): Promise<void> {
    this.flowState = AssistantFlowState.RECOGNIZING;
    this.recognitionText = '正在处理录音...';
    this.rawTranscriptText = '正在识别语音...';

    try {
      const result = await this.viewModel.stopAndProcessRecording();
      this.applyRecognitionResult(result.recognizedText, result.commandResult, result.feedback, result.responseTime);
    } catch (error) {
      this.flowState = AssistantFlowState.FAILED;
      this.recognitionText = '识别失败，请重试';
      this.rawTranscriptText = '识别失败';
      console.error('语音识别错误:', error);
    }
  }

  async testWithDataset(): Promise<void> {
    this.flowState = AssistantFlowState.EVALUATING;
    this.recognitionText = '正在使用 LibriSpeech 英文数据集评测...';

    try {
      const result = await this.viewModel.testWithDataset();
      this.recognitionText = `测试完成 - LibriSpeech 词准确率: ${result.wordAccuracy}%`;
      this.commandResult = `评测样本数: ${result.evaluatedCount}/${result.sampleCount}`;
      this.feedbackText = result.wordAccuracy >= 93 ? '评测达到 93% 目标' : '评测未达到 93% 目标';
      this.responseTime = result.avgResponseTime;
      this.evaluationAccuracy = result.wordAccuracy;
    } catch (error) {
      this.flowState = AssistantFlowState.FAILED;
      this.recognitionText = 'LibriSpeech 评测失败';
      console.error('数据集测试错误:', error);
    }
  }

  private applyRecognitionResult(recognizedText: string, commandResult: string, feedback: string, responseTime: number): void {
    this.recognitionText = recognizedText || '未识别到语音内容';
    this.rawTranscriptText = recognizedText || '';
    this.commandResult = commandResult;
    this.feedbackText = feedback;
    this.responseTime = responseTime;
  }

  build() {
    Scroll() {
      Column() {
        this.buildHeader()

        StatusPanel({
          datasetInfo: this.datasetInfo,
          flowStateLabel: getAssistantFlowLabel(this.flowState),
          evaluationAccuracy: this.evaluationAccuracy,
          responseTime: this.responseTime
        })

        InfoPanel({
          title: '语音转文字原始结果',
          value: this.rawTranscriptText,
          placeholder: '语音识别的文字将显示在这里...',
          panelBackgroundColor: '#F0F4FF',
          panelBorderColor: '#C5CAE9',
          textColor: '#333333',
          panelHeight: 100,
          editable: true
        })

        InfoPanel({
          title: '识别结果',
          value: this.recognitionText,
          placeholder: '暂无识别结果',
          panelBackgroundColor: '#F8F9FA',
          panelBorderColor: '#E8E8E8',
          textColor: '#333333',
          panelHeight: 60,
          editable: false
        })

        InfoPanel({
          title: '指令执行结果（含模拟能力）',
          value: this.commandResult,
          placeholder: '暂无指令执行结果',
          panelBackgroundColor: '#FFF8E1',
          panelBorderColor: '#FFE082',
          textColor: '#555555',
          panelHeight: 60,
          editable: false
        })

        InfoPanel({
          title: '文字反馈',
          value: this.feedbackText,
          placeholder: '暂无反馈',
          panelBackgroundColor: '#E8F5E9',
          panelBorderColor: '#A5D6A7',
          textColor: '#2E7D32',
          panelHeight: 60,
          editable: false
        })

        ControlButtons({
          isRecording: this.flowState === AssistantFlowState.RECORDING,
          isBusy: isAssistantFlowBusy(this.flowState),
          startAction: () => this.startRecognition(),
          stopAction: () => this.stopRecording(),
          evaluateAction: () => this.testWithDataset()
        })

        RecordingIndicator({
          isRecording: this.flowState === AssistantFlowState.RECORDING,
          currentAudioLevel: this.currentAudioLevel,
          audioLevels: this.audioLevels
        })
      }
      .width('100%')
      .padding({ top: 10, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7FB')
  }

  @Builder
  buildHeader() {
    Column() {
      Text('智能语音助手')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')

      Text('中文实时交互 / LibriSpeech 英文评测')
        .fontSize(13)
        .fontColor('#E8ECFF')
        .margin({ top: 6 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 24, bottom: 18 })
    .alignItems(HorizontalAlign.Start)
    .linearGradient({
      direction: GradientDirection.Right,
      colors: [['#2563EB', 0], ['#7C3AED', 1]]
    })
    .borderRadius({ bottomLeft: 16, bottomRight: 16 })
  }
}
