import {
  THEME_BORDER,
  THEME_CARD_RADIUS,
  THEME_CARD_WIDTH,
  THEME_TEXT_SECONDARY,
  THEME_FIELD_RADIUS,
  THEME_SHADOW,
  THEME_SURFACE,
  THEME_TEXT_PRIMARY
} from './AssistantTheme';

@Component
export struct InfoPanel {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop placeholder: string = '';
  @Prop panelBackgroundColor: string = THEME_SURFACE;
  @Prop panelBorderColor: string = THEME_BORDER;
  @Prop textColor: string = THEME_TEXT_SECONDARY;
  @Prop panelHeight: number = 60;
  @Prop editable: boolean = false;

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(THEME_TEXT_PRIMARY)
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (this.editable) {
        TextArea({ text: this.value, placeholder: this.placeholder })
          .width('100%')
          .height(this.panelHeight)
          .padding(12)
          .backgroundColor(this.panelBackgroundColor)
          .borderRadius(THEME_FIELD_RADIUS)
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
          .padding(12)
          .backgroundColor(this.panelBackgroundColor)
          .borderRadius(THEME_FIELD_RADIUS)
          .border({ width: 1, color: this.panelBorderColor })
          .textAlign(TextAlign.Start)
          .lineHeight(22)
      }
    }
    .width(THEME_CARD_WIDTH)
    .padding(14)
    .backgroundColor(THEME_SURFACE)
    .borderRadius(THEME_CARD_RADIUS)
    .border({ width: 1, color: THEME_BORDER })
    .margin({ bottom: 12 })
    .shadow({
      radius: 10,
      color: THEME_SHADOW,
      offsetX: 0,
      offsetY: 3
    })
  }
}
