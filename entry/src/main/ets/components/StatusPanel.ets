@Component
export struct StatusPanel {
  @Prop datasetInfo: string = '';
  @Prop evaluationAccuracy: number = 0;
  @Prop responseTime: number = 0;

  build() {
    Row() {
      this.buildStatusItem('D', '数据集', this.datasetInfo, '#4CAF50')

      Divider()
        .vertical(true)
        .height(40)
        .color('#E0E0E0')
        .strokeWidth(1)

      this.buildStatusItem(
        'A',
        '评测词准确率',
        this.evaluationAccuracy > 0 ? `${this.evaluationAccuracy}%` : '未评测',
        this.evaluationAccuracy >= 93 ? '#4CAF50' : '#FF5722'
      )

      Divider()
        .vertical(true)
        .height(40)
        .color('#E0E0E0')
        .strokeWidth(1)

      this.buildStatusItem(
        'T',
        '响应时间',
        this.responseTime > 0 ? `${this.responseTime}ms` : '未统计',
        this.responseTime > 0 && this.responseTime <= 2000 ? '#4CAF50' : '#FF5722'
      )
    }
    .width('90%')
    .height(84)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ top: 20, bottom: 15 })
    .justifyContent(FlexAlign.SpaceEvenly)
    .shadow({
      radius: 8,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  buildStatusItem(icon: string, label: string, value: string, color: string) {
    Column() {
      Text(icon)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(label)
        .fontSize(10)
        .fontColor('#8A8F98')
        .margin({ top: 4 })

      Text(value)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 2 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('30%')
    .alignItems(HorizontalAlign.Center)
  }
}
