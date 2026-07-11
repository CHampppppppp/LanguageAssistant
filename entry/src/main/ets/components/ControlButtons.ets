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
  @Prop isConversationActive: boolean = false;
  @Prop isBusy: boolean = false;
  startAction: () => Promise<void> = async () => {};
  endConversationAction: () => Promise<void> = async () => {};
  openEvaluationAction: () => void = () => {};

  build() {
    Row() {
      Button(this.isConversationActive ? '结束对话' : '开始对话')
        .width('70%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(THEME_TEXT_INVERSE)
        .backgroundColor(this.isConversationActive ? THEME_DANGER : THEME_ACCENT)
        .borderRadius(THEME_BUTTON_RADIUS)
        .opacity(this.isConversationActive || !this.isBusy ? 1 : 0.52)
        .enabled(this.isConversationActive || !this.isBusy)
        .onClick(() => {
          if (this.isConversationActive) {
            this.endConversationAction();
          } else {
            this.startAction();
          }
        })

      Button('英文评测')
        .width('26%')
        .height(50)
        .fontSize(13)
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
  }
}
