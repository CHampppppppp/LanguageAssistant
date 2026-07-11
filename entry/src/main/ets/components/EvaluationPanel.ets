import {
  THEME_ACCENT_SHADOW,
  THEME_BORDER,
  THEME_DANGER,
  THEME_SUCCESS,
  THEME_SURFACE,
  THEME_SURFACE_BLUE,
  THEME_SURFACE_MUTED,
  THEME_TEXT_INVERSE,
  THEME_TEXT_MUTED,
  THEME_TEXT_PRIMARY,
  THEME_TEXT_SECONDARY,
  THEME_WARNING
} from './AssistantTheme';

@Component
export struct EvaluationPanel {
  @Prop datasetInfo: string = '';
  @Prop evaluationAccuracy: number = 0;
  @Prop evaluationResponseTime: number = 0;
  @Prop evaluationStatusText: string = '';
  @Prop evaluationSampleInfo: string = '';
  @Prop isEvaluationRunning: boolean = false;
  closeAction: () => void = () => {};
  evaluateAction: () => Promise<void> = async () => {};

  build() {
    Column() {
      Row() {
        Column() {
          Text('LibriSpeech 英文评测')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(THEME_TEXT_PRIMARY)

          Text('用于验收英文数据集准确率和响应时间')
            .fontSize(12)
            .fontColor(THEME_TEXT_MUTED)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('关闭')
          .height(34)
          .fontSize(13)
          .fontColor(THEME_TEXT_SECONDARY)
          .backgroundColor(THEME_SURFACE_MUTED)
          .border({ width: 1, color: THEME_BORDER })
          .borderRadius(6)
          .enabled(!this.isEvaluationRunning)
          .opacity(this.isEvaluationRunning ? 0.5 : 1)
          .onClick(() => {
            this.closeAction();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 14 })

      Row() {
        this.buildMetric('数据集', this.datasetInfo, THEME_TEXT_PRIMARY)
        this.buildMetric(
          '词准确率',
          this.evaluationAccuracy > 0 ? `${this.evaluationAccuracy}%` : '未评测',
          this.evaluationAccuracy >= 93 ? THEME_SUCCESS : THEME_WARNING
        )
        this.buildMetric(
          '平均响应',
          this.evaluationResponseTime > 0 ? `${this.evaluationResponseTime}ms` : '未统计',
          this.evaluationResponseTime > 0 && this.evaluationResponseTime <= 2000 ? THEME_SUCCESS : THEME_DANGER
        )
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      this.buildTextBlock('评测状态', this.evaluationStatusText, '尚未运行评测', 54, THEME_SURFACE_MUTED)
      this.buildTextBlock('样本摘要', this.evaluationSampleInfo, '评测后展示样本摘要', 118, THEME_SURFACE_BLUE)

      Button(this.isEvaluationRunning ? '评测中...' : '开始英文评测')
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(THEME_TEXT_INVERSE)
        .backgroundColor(THEME_WARNING)
        .borderRadius(8)
        .enabled(!this.isEvaluationRunning)
        .opacity(this.isEvaluationRunning ? 0.62 : 1)
        .onClick(() => {
          this.evaluateAction();
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor(THEME_SURFACE)
    .border({ width: 1, color: THEME_BORDER })
    .borderRadius({ topLeft: 12, topRight: 12, bottomLeft: 0, bottomRight: 0 })
    .shadow({
      radius: 18,
      color: THEME_ACCENT_SHADOW,
      offsetX: 0,
      offsetY: -5
    })
  }

  @Builder
  buildMetric(label: string, value: string, color: string) {
    Column() {
      Text(label)
        .fontSize(11)
        .fontColor(THEME_TEXT_MUTED)

      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 4 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('31%')
    .height(58)
    .padding(8)
    .backgroundColor(THEME_SURFACE_MUTED)
    .border({ width: 1, color: THEME_BORDER })
    .borderRadius(7)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildTextBlock(title: string, value: string, placeholder: string, blockHeight: number, backgroundColor: string) {
    Column() {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(THEME_TEXT_PRIMARY)
        .margin({ bottom: 8 })

      Text(value || placeholder)
        .fontSize(13)
        .fontColor(THEME_TEXT_SECONDARY)
        .width('100%')
        .height(blockHeight)
        .padding(10)
        .backgroundColor(backgroundColor)
        .border({ width: 1, color: THEME_BORDER })
        .borderRadius(7)
        .lineHeight(20)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 12 })
  }
}
