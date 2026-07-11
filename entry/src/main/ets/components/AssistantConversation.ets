import {
  THEME_ACCENT,
  THEME_BORDER,
  THEME_CARD_WIDTH,
  THEME_SURFACE,
  THEME_TEXT_INVERSE,
  THEME_TEXT_PRIMARY
} from './AssistantTheme';

@Component
export struct AssistantConversation {
  @Prop rawTranscriptText: string = '';
  @Prop feedbackText: string = '';

  build() {
    Column() {
      if (this.rawTranscriptText !== '') {
        this.buildUserBubble(this.rawTranscriptText)
        this.buildAssistantBubble(this.feedbackText || '我暂时无法处理这条语音。', false)
      } else {
        this.buildAssistantBubble(this.feedbackText || '我在这里，点击开始对话即可语音交互。', true)
      }

      Blank()
        .layoutWeight(1)
    }
    .width(THEME_CARD_WIDTH)
    .height('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  buildAssistantBubble(text: string, compact: boolean) {
    Row() {
      Text('AI')
        .width(32)
        .height(32)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(THEME_TEXT_INVERSE)
        .textAlign(TextAlign.Center)
        .backgroundColor(THEME_ACCENT)
        .borderRadius(16)
        .margin({ right: 8 })

      Text(text)
        .fontSize(15)
        .fontColor(THEME_TEXT_PRIMARY)
        .lineHeight(22)
        .padding({ left: 12, right: 12, top: compact ? 10 : 12, bottom: compact ? 10 : 12 })
        .backgroundColor(THEME_SURFACE)
        .border({ width: 1, color: THEME_BORDER })
        .borderRadius(8)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 12 })
  }

  @Builder
  buildUserBubble(text: string) {
    Row() {
      Blank()
        .layoutWeight(1)

      Text(text)
        .fontSize(15)
        .fontColor(THEME_TEXT_INVERSE)
        .lineHeight(22)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor(THEME_ACCENT)
        .borderRadius(8)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('76%')
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

}
