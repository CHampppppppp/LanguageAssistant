@Component
export struct ControlButtons {
  @Prop isRecording: boolean = false;
  @Prop isBusy: boolean = false;
  startAction: () => Promise<void> = async () => {};
  stopAction: () => Promise<void> = async () => {};
  evaluateAction: () => Promise<void> = async () => {};

  build() {
    Row() {
      Button(this.isRecording ? '停止录音' : '开始识别')
        .width('45%')
        .height(52)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.isRecording ? '#D64545' : '#2563EB')
        .borderRadius(12)
        .enabled(this.isRecording || !this.isBusy)
        .onClick(() => {
          if (this.isRecording) {
            this.stopAction();
          } else {
            this.startAction();
          }
        })

      Button('英文评测')
        .width('45%')
        .height(52)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor('#F97316')
        .borderRadius(12)
        .enabled(!this.isBusy)
        .onClick(() => {
          this.evaluateAction();
        })
    }
    .width('90%')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ bottom: 20 })
  }
}
