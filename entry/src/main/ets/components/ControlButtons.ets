import {
  THEME_ACCENT,
  THEME_BUTTON_RADIUS,
  THEME_CARD_WIDTH,
  THEME_DANGER,
  THEME_TEXT_INVERSE,
  THEME_WARNING
} from './AssistantTheme';

@Component
export struct ControlButtons {
  @Prop isRecording: boolean = false;
  @Prop isBusy: boolean = false;
  startAction: () => Promise<void> = async () => {};
  stopAction: () => Promise<void> = async () => {};
  openEvaluationAction: () => void = () => {};

  build() {
    Row() {
      Button(this.isRecording ? '停止录音' : '开始识别')
        .width('68%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(THEME_TEXT_INVERSE)
        .backgroundColor(this.isRecording ? THEME_DANGER : THEME_ACCENT)
        .borderRadius(THEME_BUTTON_RADIUS)
        .opacity(this.isRecording || !this.isBusy ? 1 : 0.52)
        .enabled(this.isRecording || !this.isBusy)
        .onClick(() => {
          if (this.isRecording) {
            this.stopAction();
          } else {
            this.startAction();
          }
        })

      Button('评测')
        .width('28%')
        .height(50)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(THEME_WARNING)
        .backgroundColor('#FFF7E8')
        .borderRadius(THEME_BUTTON_RADIUS)
        .border({ width: 1, color: THEME_WARNING })
        .opacity(!this.isBusy ? 1 : 0.52)
        .enabled(!this.isBusy)
        .onClick(() => {
          this.openEvaluationAction();
        })
    }
    .width(THEME_CARD_WIDTH)
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ bottom: 16 })
  }
}
