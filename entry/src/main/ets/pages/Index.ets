import { AssistantUiAction, RecognitionResult, TestDetail, TestResult, VoiceAssistantViewModel } from '../viewmodel/VoiceAssistantViewModel';
import { StatusPanel } from '../components/StatusPanel';
import { InfoPanel } from '../components/InfoPanel';
import { ControlButtons } from '../components/ControlButtons';
import { RecordingIndicator } from '../components/RecordingIndicator';
import { EvaluationPanel } from '../components/EvaluationPanel';
import { AssistantFlowState, getAssistantFlowLabel, isAssistantFlowBusy } from '../viewmodel/AssistantFlowState';
import {
  THEME_ACCENT,
  THEME_ACCENT_DARK,
  THEME_BORDER,
  THEME_CARD_WIDTH,
  THEME_PAGE_BACKGROUND,
  THEME_SHADOW_STRONG,
  THEME_SURFACE,
  THEME_SURFACE_AMBER,
  THEME_SURFACE_BLUE,
  THEME_SURFACE_GREEN,
  THEME_SURFACE_RED,
  THEME_TEXT_INVERSE,
  THEME_TEXT_ON_ACCENT_MUTED,
  THEME_TEXT_PRIMARY,
  THEME_TEXT_SECONDARY,
  THEME_DANGER,
  THEME_ACCENT_SHADOW
} from '../components/AssistantTheme';

@Entry
@Component
struct Index {
  @State viewModel: VoiceAssistantViewModel = new VoiceAssistantViewModel();
  @State recognitionText: string = '说出你的指令，例如：现在几点了 / 准确率评测';
  @State commandResult: string = '';
  @State feedbackText: string = '我在这里，点击麦克风开始语音交互。';
  @State flowState: AssistantFlowState = AssistantFlowState.IDLE;
  @State semanticConfidence: number = 0;
  @State assistantResponseTime: number = 0;
  @State evaluationAccuracy: number = 0;
  @State evaluationResponseTime: number = 0;
  @State datasetInfo: string = 'LibriSpeech 英文评测资源';
  @State evaluationStatusText: string = '尚未运行评测';
  @State evaluationSampleInfo: string = '等待开始评测';
  @State isEvaluationPanelVisible: boolean = false;
  @State isEvaluationRunning: boolean = false;
  @State rawTranscriptText: string = '';
  @State audioLevels: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  @State currentAudioLevel: number = 0;
  @State errorToastText: string = '';
  private errorToastTimer: number = -1;

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
    this.clearErrorToastTimer();
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
    this.feedbackText = '我正在听。';
    this.rawTranscriptText = '';
    this.semanticConfidence = 0;
    this.assistantResponseTime = 0;
    this.errorToastText = '';
    this.audioLevels = [0, 0, 0, 0, 0, 0, 0, 0, 0];

    try {
      await this.viewModel.startRecording();
    } catch (error) {
      const errMsg: string = this.formatErrorForUi(error as Error);
      this.flowState = AssistantFlowState.FAILED;
      this.recognitionText = '录音启动失败，请检查麦克风权限';
      this.rawTranscriptText = '录音启动失败';
      this.feedbackText = '录音启动失败，请检查麦克风权限。';
      this.showErrorToast(errMsg);
      console.error('录音启动错误:', error);
    }
  }

  async stopRecording(): Promise<void> {
    this.flowState = AssistantFlowState.RECOGNIZING;
    this.recognitionText = '正在处理录音...';
    this.rawTranscriptText = '正在识别语音...';

    try {
      const result = await this.viewModel.stopAndProcessRecording();
      this.applyRecognitionResult(result);
    } catch (error) {
      const errMsg: string = this.formatErrorForUi(error as Error);
      this.flowState = AssistantFlowState.FAILED;
      this.recognitionText = '识别失败，请重试';
      this.rawTranscriptText = '识别失败';
      this.feedbackText = '识别失败，请重试。';
      this.showErrorToast(errMsg);
      console.error('语音识别错误:', error);
    }
  }

  async testWithDataset(): Promise<void> {
    if (this.isEvaluationRunning) {
      return;
    }
    this.isEvaluationPanelVisible = true;
    this.isEvaluationRunning = true;
    this.flowState = AssistantFlowState.EVALUATING;
    this.evaluationStatusText = '正在使用 LibriSpeech 英文数据集评测...';
    this.errorToastText = '';

    try {
      const result = await this.viewModel.testWithDataset();
      this.evaluationStatusText = result.wordAccuracy >= 93 ? '评测达到 93% 目标' : '评测未达到 93% 目标';
      this.evaluationSampleInfo = this.buildEvaluationSampleInfo(result);
      this.feedbackText = `LibriSpeech 英文评测完成，词准确率 ${result.wordAccuracy}%。`;
      this.evaluationResponseTime = result.avgResponseTime;
      this.evaluationAccuracy = result.wordAccuracy;
    } catch (error) {
      const errMsg: string = this.formatErrorForUi(error as Error);
      this.flowState = AssistantFlowState.FAILED;
      this.evaluationStatusText = 'LibriSpeech 评测失败';
      this.evaluationSampleInfo = '请检查数据集、网络或 ASR 服务配置';
      this.feedbackText = 'LibriSpeech 英文评测失败，请检查评测资源和服务配置。';
      this.showErrorToast(errMsg);
      console.error('数据集测试错误:', error);
    } finally {
      this.isEvaluationRunning = false;
    }
  }

  private applyRecognitionResult(result: RecognitionResult): void {
    this.recognitionText = result.recognizedText || '未识别到语音内容';
    this.rawTranscriptText = result.recognizedText || '';
    this.commandResult = result.commandResult;
    this.feedbackText = result.feedback;
    this.semanticConfidence = result.semanticConfidence;
    this.assistantResponseTime = result.responseTime;
    if (result.errorDetail) {
      this.showErrorToast(result.errorDetail);
    } else {
      this.errorToastText = '';
    }

    if (result.uiAction === AssistantUiAction.OPEN_EVALUATION_PANEL) {
      this.isEvaluationPanelVisible = true;
      this.evaluationStatusText = '已打开 LibriSpeech 英文评测模块';
    }
  }

  private showErrorToast(message: string): void {
    if (!message) {
      return;
    }

    this.errorToastText = message;
    this.clearErrorToastTimer();
    this.errorToastTimer = setTimeout(() => {
      this.errorToastText = '';
      this.errorToastTimer = -1;
    }, 2000);
  }

  private clearErrorToastTimer(): void {
    if (this.errorToastTimer >= 0) {
      clearTimeout(this.errorToastTimer);
      this.errorToastTimer = -1;
    }
  }

  private formatErrorForUi(error: Error): string {
    if (error.message) {
      return error.message;
    }
    return String(error);
  }

  private buildEvaluationSampleInfo(result: TestResult): string {
    const summary: string = `评测样本数: ${result.evaluatedCount}/${result.sampleCount}`;
    if (result.details.length === 0) {
      return summary;
    }

    const firstDetail: TestDetail = result.details[0];
    const wordAccuracy: number = firstDetail.wordAccuracy <= 1 ?
      Number((firstDetail.wordAccuracy * 100).toFixed(2)) :
      Number(firstDetail.wordAccuracy.toFixed(2));
    return `${summary}\n样本: ${firstDetail.sampleId}\n词准确率: ${wordAccuracy}%\n基准: ${firstDetail.groundTruth}\n识别: ${firstDetail.recognizedText}`;
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll() {
          Column() {
            this.buildHeader()

          StatusPanel({
            flowStateLabel: getAssistantFlowLabel(this.flowState),
            responseTime: this.assistantResponseTime,
            semanticConfidence: this.semanticConfidence
          })

          RecordingIndicator({
            isRecording: this.flowState === AssistantFlowState.RECORDING,
            currentAudioLevel: this.currentAudioLevel,
            audioLevels: this.audioLevels
          })

          InfoPanel({
            title: '我听到的内容',
            value: this.rawTranscriptText,
            placeholder: '语音识别的文字将显示在这里...',
            panelBackgroundColor: THEME_SURFACE_BLUE,
            panelBorderColor: THEME_BORDER,
            textColor: THEME_TEXT_PRIMARY,
            panelHeight: 90,
            editable: true
          })

          InfoPanel({
            title: '助手理解',
            value: this.recognitionText,
            placeholder: '暂无识别结果',
            panelBackgroundColor: THEME_SURFACE,
            panelBorderColor: THEME_BORDER,
            textColor: THEME_TEXT_PRIMARY,
            panelHeight: 58,
            editable: false
          })

          InfoPanel({
            title: '执行结果',
            value: this.commandResult,
            placeholder: '暂无指令执行结果',
            panelBackgroundColor: THEME_SURFACE_AMBER,
            panelBorderColor: THEME_BORDER,
            textColor: THEME_TEXT_SECONDARY,
            panelHeight: 58,
            editable: false
          })

          InfoPanel({
            title: '助手回复',
            value: this.feedbackText,
            placeholder: '暂无反馈',
            panelBackgroundColor: THEME_SURFACE_GREEN,
            panelBorderColor: THEME_BORDER,
            textColor: THEME_TEXT_SECONDARY,
            panelHeight: 58,
            editable: false
          })

          ControlButtons({
            isRecording: this.flowState === AssistantFlowState.RECORDING,
            isBusy: isAssistantFlowBusy(this.flowState),
            startAction: () => this.startRecognition(),
            stopAction: () => this.stopRecording(),
            openEvaluationAction: () => this.openEvaluationPanel()
          })
          }
          .width('100%')
          .padding({ top: 0, bottom: 24 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(THEME_PAGE_BACKGROUND)

        if (this.isEvaluationPanelVisible) {
          EvaluationPanel({
            datasetInfo: this.datasetInfo,
            evaluationAccuracy: this.evaluationAccuracy,
            evaluationResponseTime: this.evaluationResponseTime,
            evaluationStatusText: this.evaluationStatusText,
            evaluationSampleInfo: this.evaluationSampleInfo,
            isEvaluationRunning: this.isEvaluationRunning,
            closeAction: () => this.closeEvaluationPanel(),
            evaluateAction: () => this.testWithDataset()
          })
        }
      }
      .width('100%')
      .height('100%')

      if (this.errorToastText !== '') {
        this.buildErrorToast()
      }
    }
    .width('100%')
    .height('100%')
  }

  private openEvaluationPanel(): void {
    this.isEvaluationPanelVisible = true;
  }

  private closeEvaluationPanel(): void {
    if (!this.isEvaluationRunning) {
      this.isEvaluationPanelVisible = false;
    }
  }

  @Builder
  buildHeader() {
    Column() {
      Text('智能语音助手')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(THEME_TEXT_INVERSE)

      Text('实时语音识别、语义理解、指令执行、文字反馈')
        .fontSize(13)
        .fontColor(THEME_TEXT_ON_ACCENT_MUTED)
        .margin({ top: 5 })
    }
    .width(THEME_CARD_WIDTH)
    .padding({ left: 18, right: 18, top: 22, bottom: 18 })
    .margin({ top: 12, bottom: 14 })
    .alignItems(HorizontalAlign.Start)
    .linearGradient({
      direction: GradientDirection.Right,
      colors: [[THEME_ACCENT_DARK, 0], [THEME_ACCENT, 1]]
    })
    .borderRadius(8)
    .shadow({
      radius: 12,
      color: THEME_ACCENT_SHADOW,
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  buildErrorToast() {
    Text(this.errorToastText)
      .fontSize(12)
      .fontColor(THEME_DANGER)
      .lineHeight(18)
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width(260)
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(THEME_SURFACE_RED)
      .border({ width: 1, color: THEME_DANGER })
      .borderRadius(8)
      .margin({ top: 16, right: 14 })
      .shadow({
        radius: 10,
        color: THEME_SHADOW_STRONG,
        offsetX: 0,
        offsetY: 3
      })
  }
}
