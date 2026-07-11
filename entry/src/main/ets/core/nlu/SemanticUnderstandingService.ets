import { VoiceCommand } from '../../model/VoiceCommand';

export interface SemanticUnderstandingService {
  understand(text: string): Promise<VoiceCommand>;
}
