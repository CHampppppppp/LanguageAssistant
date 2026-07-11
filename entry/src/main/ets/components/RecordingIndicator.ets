import {
  THEME_ACCENT,
  THEME_BORDER,
  THEME_CARD_RADIUS,
  THEME_CARD_WIDTH,
  THEME_DANGER,
  THEME_SURFACE_RED
} from './AssistantTheme';

@Component
export struct RecordingIndicator {
  @Prop isRecording: boolean = false;
  @Prop currentAudioLevel: number = 0;
  @Prop audioLevels: number[] = [];

  build() {
    if (this.isRecording) {
      Column() {
        Text(`正在录音，音量 ${Math.round(this.currentAudioLevel)}%`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(THEME_DANGER)

        Row() {
          ForEach(this.audioLevels, (height: number) => {
            Column()
              .width(4)
              .height(height)
              .backgroundColor(this.currentAudioLevel > 5 ? THEME_ACCENT : THEME_BORDER)
              .margin({ left: 3 })
              .borderRadius(2)
          })
        }
        .height(40)
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 10 })
        .justifyContent(FlexAlign.Center)

        if (this.currentAudioLevel === 0) {
          Text('未检测到音频输入，请检查模拟器输入源')
            .fontSize(12)
            .fontColor(THEME_DANGER)
            .margin({ top: 8 })
        }
      }
      .width(THEME_CARD_WIDTH)
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .backgroundColor(THEME_SURFACE_RED)
      .borderRadius(THEME_CARD_RADIUS)
      .border({ width: 1, color: THEME_BORDER })
      .margin({ top: 2 })
    }
  }
}
