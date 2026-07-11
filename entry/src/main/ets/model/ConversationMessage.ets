export enum ConversationRole {
  USER = 'user',
  ASSISTANT = 'assistant'
}

export interface ConversationMessage {
  id: string;
  role: ConversationRole;
  content: string;
}
