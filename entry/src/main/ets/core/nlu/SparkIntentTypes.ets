export interface SparkMessage {
  role: string;
  content: string;
}

export interface SparkResponseFormat {
  type: string;
}

export interface SparkChatRequest {
  model: string;
  messages: SparkMessage[];
  temperature: number;
  max_tokens: number;
  stream: boolean;
  response_format: SparkResponseFormat;
}

export interface SparkChoiceMessage {
  content: string;
}

export interface SparkChoice {
  message: SparkChoiceMessage;
}

export interface SparkChatResponse {
  choices?: SparkChoice[];
  code?: number;
  message?: string;
}

export interface SparkIntentEntities {
  app_name?: string;
  music_name?: string;
  hour?: string;
  minute?: string;
  volume_target?: string;
  volume_unit?: string;
}

export interface SparkIntentResult {
  intent: string;
  confidence: number;
  entities?: SparkIntentEntities;
}
