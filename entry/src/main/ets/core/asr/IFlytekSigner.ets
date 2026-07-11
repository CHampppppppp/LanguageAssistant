import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

export class IFlytekSigner {
  private static readonly HMAC_KEY_ALGORITHM: string = 'HMAC';
  private static readonly HMAC_DIGEST_ALGORITHM: string = 'SHA256';

  async generateSignature(apiSecret: string, host: string, date: string, requestLine: string): Promise<string> {
    const signatureOrigin: string = `host: ${host}\ndate: ${date}\n${requestLine}`;
    const signatureBuffer: ArrayBuffer = await this.hmacSha256(apiSecret, signatureOrigin);
    return this.arrayBufferToBase64(signatureBuffer);
  }

  private async hmacSha256(key: string, data: string): Promise<ArrayBuffer> {
    try {
      const encoder: util.TextEncoder = new util.TextEncoder();
      const keyData: Uint8Array = encoder.encode(key);
      const messageData: Uint8Array = encoder.encode(data);

      const keyBlob: cryptoFramework.DataBlob = { data: keyData };
      const messageBlob: cryptoFramework.DataBlob = { data: messageData };
      const symKeyGenerator: cryptoFramework.SymKeyGenerator =
        cryptoFramework.createSymKeyGenerator(IFlytekSigner.HMAC_KEY_ALGORITHM);
      const symKey: cryptoFramework.SymKey = await symKeyGenerator.convertKey(keyBlob);
      const mac: cryptoFramework.Mac = cryptoFramework.createMac(IFlytekSigner.HMAC_DIGEST_ALGORITHM);

      await mac.init(symKey);
      await mac.update(messageBlob);
      const macResult: cryptoFramework.DataBlob = await mac.doFinal();
      return macResult.data;
    } catch (error) {
      throw new Error(`HMAC-SHA256 签名失败: ${this.formatErrorMessage(error)}`);
    }
  }

  private formatErrorMessage(error: object): string {
    const errorRecord: Record<string, string> = error as Record<string, string>;
    if (errorRecord.message && errorRecord.message !== '') {
      return errorRecord.message;
    }
    return String(error);
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes: Uint8Array = new Uint8Array(buffer);
    const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result: string = '';
    let i: number = 0;

    while (i < bytes.length) {
      const byte1: number = bytes[i++];
      const hasByte2: boolean = i < bytes.length;
      const byte2: number = hasByte2 ? bytes[i++] : 0;
      const hasByte3: boolean = i < bytes.length;
      const byte3: number = hasByte3 ? bytes[i++] : 0;

      result += chars.charAt(byte1 >> 2);
      result += chars.charAt(((byte1 & 3) << 4) | (byte2 >> 4));
      result += hasByte2 ? chars.charAt(((byte2 & 15) << 2) | (byte3 >> 6)) : '=';
      result += hasByte3 ? chars.charAt(byte3 & 63) : '=';
    }

    return result;
  }
}
