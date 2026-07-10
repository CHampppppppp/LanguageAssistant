@Component
export struct InfoPanel {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop placeholder: string = '';
  @Prop panelBackgroundColor: string = '#FFFFFF';
  @Prop panelBorderColor: string = '#E8E8E8';
  @Prop textColor: string = '#333333';
  @Prop panelHeight: number = 60;
  @Prop editable: boolean = false;

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.editable) {
        TextArea({ text: this.value, placeholder: this.placeholder })
          .width('100%')
          .height(this.panelHeight)
          .padding(12)
          .backgroundColor(this.panelBackgroundColor)
          .borderRadius(10)
          .border({ width: 1, color: this.panelBorderColor })
          .fontSize(15)
          .fontColor(this.textColor)
          .textAlign(TextAlign.Start)
      } else {
        Text(this.value || this.placeholder)
          .fontSize(14)
          .fontColor(this.textColor)
          .width('100%')
          .height(this.panelHeight)
          .padding(14)
          .backgroundColor(this.panelBackgroundColor)
          .borderRadius(10)
          .border({ width: 1, color: this.panelBorderColor })
          .textAlign(TextAlign.Start)
          .lineHeight(22)
      }
    }
    .width('90%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 15 })
    .shadow({
      radius: 8,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }
}
