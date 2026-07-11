import {
  THEME_ACCENT,
  THEME_BORDER,
  THEME_CARD_WIDTH,
  THEME_DANGER,
  THEME_SURFACE,
  THEME_SURFACE_BLUE,
  THEME_SURFACE_GREEN,
  THEME_SURFACE_MUTED,
  THEME_TEXT_INVERSE,
  THEME_TEXT_MUTED,
  THEME_TEXT_PRIMARY,
  THEME_TEXT_SECONDARY
} from './AssistantTheme';

@Component
export struct AssistantConversation {
  @Prop rawTranscriptText: string = '';
  @Prop recognitionText: string = '';
  @Prop commandResult: string = '';
  @Prop feedbackText: string = '';
  @Prop isRecording: boolean = false;
  @Prop currentAudioLevel: number = 0;
  @Prop audioLevels: number[] = [];

  build() {
    Column() {
      this.buildAssistantBubble(this.feedbackText || '我在这里，点击麦克风开始语音交互。', true)

      if (this.rawTranscriptText !== '') {
        this.buildUserBubble(this.rawTranscriptText)
      }

      if (this.isRecording) {
        this.buildListeningBubble()
      }

      if (this.commandResult !== '') {
        this.buildExecutionBubble()
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

  @Builder
  buildListeningBubble() {
    Row() {
      Text('AI')
        .width(32)
        .height(32)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(THEME_TEXT_INVERSE)
        .textAlign(TextAlign.Center)
        .backgroundColor(THEME_DANGER)
        .borderRadius(16)
        .margin({ right: 8 })

      Column() {
        Text(`正在听，音量 ${Math.round(this.currentAudioLevel)}%`)
          .fontSize(14)
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
        .height(36)
        .alignItems(VerticalAlign.Bottom)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 8 })

        if (this.currentAudioLevel === 0) {
          Text('未检测到音频输入')
            .fontSize(12)
            .fontColor(THEME_TEXT_MUTED)
            .margin({ top: 6 })
        }
      }
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(THEME_SURFACE_BLUE)
      .border({ width: 1, color: THEME_BORDER })
      .borderRadius(8)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 12 })
  }

  @Builder
  buildExecutionBubble() {
    Row() {
      Blank()
        .width(40)

      Column() {
        Text('执行结果')
          .fontSize(12)
          .fontColor(THEME_TEXT_MUTED)
          .margin({ bottom: 5 })

        Text(this.commandResult)
          .fontSize(13)
          .fontColor(THEME_TEXT_SECONDARY)
          .lineHeight(20)
      }
      .width('82%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(this.commandResult.includes('模拟') ? THEME_SURFACE_MUTED : THEME_SURFACE_GREEN)
      .border({ width: 1, color: THEME_BORDER })
      .borderRadius(8)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }
}
