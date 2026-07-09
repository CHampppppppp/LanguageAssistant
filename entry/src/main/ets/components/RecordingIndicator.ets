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
          .fontColor('#D64545')

        Row() {
          ForEach(this.audioLevels, (height: number) => {
            Column()
              .width(4)
              .height(height)
              .backgroundColor(this.currentAudioLevel > 5 ? '#2563EB' : '#CCCCCC')
              .margin({ left: 3 })
              .borderRadius(2)
          })
        }
        .height(40)
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 10 })
        .justifyContent(FlexAlign.Center)

        if (this.currentAudioLevel === 0) {
          Text('未检测到音频输入，请检查麦克风权限')
            .fontSize(12)
            .fontColor('#D64545')
            .margin({ top: 8 })
        }
      }
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })
      .backgroundColor('#FFF1F1')
      .borderRadius(12)
      .border({ width: 1, color: '#FFCDD2' })
      .margin({ top: 10 })
    }
  }
}
