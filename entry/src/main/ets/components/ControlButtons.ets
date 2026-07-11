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
  @Prop currentAudioLevel: number = 0;
  @Prop audioLevels: number[] = [];
  startAction: () => Promise<void> = async () => {};
  endConversationAction: () => Promise<void> = async () => {};
  openEvaluationAction: () => void = () => {};

  build() {
    Row() {
      if (this.isConversationActive) {
        Button() {
          Row() {
            ForEach(this.audioLevels, (height: number) => {
              Column()
                .width(4)
                .height(Math.max(height, 5))
                .backgroundColor(THEME_TEXT_INVERSE)
                .opacity(this.currentAudioLevel > 0 ? 1 : 0.45)
                .margin({ left: 3, right: 3 })
                .borderRadius(2)
            })
          }
          .height(34)
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .width('70%')
        .height(50)
        .backgroundColor(THEME_DANGER)
        .borderRadius(THEME_BUTTON_RADIUS)
        .onClick(() => {
          this.endConversationAction();
        })
      } else {
        Button('开始对话')
          .width('70%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(THEME_TEXT_INVERSE)
          .backgroundColor(THEME_ACCENT)
          .borderRadius(THEME_BUTTON_RADIUS)
          .opacity(!this.isBusy ? 1 : 0.52)
          .enabled(!this.isBusy)
          .onClick(() => {
            this.startAction();
          })
      }

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
