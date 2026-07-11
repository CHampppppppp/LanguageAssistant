import { VoiceIntent } from './VoiceIntent';

export interface IntentRule {
  intent: VoiceIntent;
  patterns: RegExp[];
  keywords: string[];
  patternConfidence: number;
}

export const INTENT_RULES: IntentRule[] = [
  {
    intent: VoiceIntent.TIME_QUERY,
    patterns: [new RegExp('现在几点'), new RegExp('当前时间'), new RegExp('几点了'), new RegExp('查询时间')],
    keywords: ['时间', '几点', '时刻'],
    patternConfidence: 0.95
  },
  {
    intent: VoiceIntent.WEATHER_QUERY,
    patterns: [new RegExp('天气怎么样'), new RegExp('查询天气'), new RegExp('今天天气'), new RegExp('明天天气')],
    keywords: ['天气', '温度', '下雨'],
    patternConfidence: 0.95
  },
  {
    intent: VoiceIntent.PLAY_MUSIC,
    patterns: [new RegExp('播放.+'), new RegExp('播放音乐'), new RegExp('播放歌曲'), new RegExp('听歌')],
    keywords: ['播放', '音乐', '歌曲', '听歌'],
    patternConfidence: 0.95
  },
  {
    intent: VoiceIntent.STOP_MUSIC,
    patterns: [new RegExp('停止播放'), new RegExp('暂停音乐'), new RegExp('停止音乐')],
    keywords: ['停止', '暂停', '音乐'],
    patternConfidence: 0.95
  },
  {
    intent: VoiceIntent.NEXT_MUSIC,
    patterns: [new RegExp('下一首'), new RegExp('切歌'), new RegExp('下一曲')],
    keywords: ['下一首', '切歌', '下一曲'],
    patternConfidence: 0.95
  },
  {
    intent: VoiceIntent.VOLUME_SET,
    patterns: [
      new RegExp('(?:音量|声音).*(?:调|设|设置|开)到(?:\\d+(?:%|％|格|档)|百分之\\d+)'),
      new RegExp('(?:把)?(?:音量|声音)(?:调|设|设置|开)为(?:\\d+(?:%|％|格|档)|百分之\\d+)')
    ],
    keywords: ['音量', '声音', '调到', '设为', '设置', '百分之', '格', '档'],
    patternConfidence: 0.97
  },
  {
    intent: VoiceIntent.VOLUME_UP,
    patterns: [new RegExp('音量调大'), new RegExp('增大音量'), new RegExp('声音大点'), new RegExp('把声音开大')],
    keywords: ['音量', '声音', '调大', '增大', '大点', '开大'],
    patternConfidence: 0.95
  },
  {
    intent: VoiceIntent.VOLUME_DOWN,
    patterns: [new RegExp('音量调小'), new RegExp('减小音量'), new RegExp('声音小点'), new RegExp('把声音关小')],
    keywords: ['音量', '声音', '调小', '减小', '小点', '关小'],
    patternConfidence: 0.95
  },
  {
    intent: VoiceIntent.SET_ALARM,
    patterns: [new RegExp('设置.*闹钟'), new RegExp('定个闹钟'), new RegExp('提醒我')],
    keywords: ['设置', '闹钟', '提醒'],
    patternConfidence: 0.95
  },
  {
    intent: VoiceIntent.ACCURACY_EVALUATION,
    patterns: [
      new RegExp('准确率评测'),
      new RegExp('打开.*评测'),
      new RegExp('英文评测'),
      new RegExp('性能评测'),
      new RegExp('性能测试'),
      new RegExp('测试.*准确率'),
      new RegExp('librispeech评测')
    ],
    keywords: ['准确率', '评测', '英文', '性能', '测试', 'librispeech'],
    patternConfidence: 0.96
  },
  {
    intent: VoiceIntent.OPEN_APP,
    patterns: [new RegExp('打开.+'), new RegExp('启动.+')],
    keywords: ['打开', '启动', '应用', '软件'],
    patternConfidence: 0.95
  },
  {
    intent: VoiceIntent.CLOSE_APP,
    patterns: [new RegExp('关闭.+'), new RegExp('退出.+')],
    keywords: ['关闭', '退出', '应用', '软件'],
    patternConfidence: 0.95
  }
];
