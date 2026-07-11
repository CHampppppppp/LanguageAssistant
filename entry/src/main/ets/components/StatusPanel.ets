import {
  THEME_ACCENT,
  THEME_BORDER,
  THEME_CARD_RADIUS,
  THEME_CARD_WIDTH,
  THEME_DANGER,
  THEME_SUCCESS,
  THEME_SURFACE,
  THEME_SHADOW_STRONG,
  THEME_TEXT_MUTED,
  THEME_TEXT_PRIMARY
} from './AssistantTheme';

@Component
export struct StatusPanel {
  @Prop datasetInfo: string = '';
  @Prop flowStateLabel: string = '';
  @Prop evaluationAccuracy: number = 0;
  @Prop responseTime: number = 0;

  build() {
    Row() {
      this.buildStatusItem('S', '流程状态', this.flowStateLabel || '待命', THEME_ACCENT)

      Divider()
        .vertical(true)
        .height(38)
        .color(THEME_BORDER)
        .strokeWidth(1)

      this.buildStatusItem('D', '数据集', this.datasetInfo, THEME_SUCCESS)

      Divider()
        .vertical(true)
        .height(38)
        .color(THEME_BORDER)
        .strokeWidth(1)

      this.buildStatusItem(
        'A',
        '评测词准确率',
        this.evaluationAccuracy > 0 ? `${this.evaluationAccuracy}%` : '未评测',
        this.evaluationAccuracy >= 93 ? THEME_SUCCESS : THEME_DANGER
      )

      Divider()
        .vertical(true)
        .height(38)
        .color(THEME_BORDER)
        .strokeWidth(1)

      this.buildStatusItem(
        'T',
        '响应时间',
        this.responseTime > 0 ? `${this.responseTime}ms` : '未统计',
        this.responseTime > 0 && this.responseTime <= 2000 ? THEME_SUCCESS : THEME_DANGER
      )
    }
    .width(THEME_CARD_WIDTH)
    .height(82)
    .backgroundColor(THEME_SURFACE)
    .borderRadius(THEME_CARD_RADIUS)
    .border({ width: 1, color: THEME_BORDER })
    .margin({ bottom: 12 })
    .justifyContent(FlexAlign.SpaceEvenly)
    .shadow({
      radius: 10,
      color: THEME_SHADOW_STRONG,
      offsetX: 0,
      offsetY: 3
    })
  }

  @Builder
  buildStatusItem(icon: string, label: string, value: string, color: string) {
    Column() {
      Text(icon)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(label)
        .fontSize(10)
        .fontColor(THEME_TEXT_MUTED)
        .margin({ top: 4 })

      Text(value)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(THEME_TEXT_PRIMARY)
        .margin({ top: 2 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('23%')
    .alignItems(HorizontalAlign.Center)
  }
}
