/**
 * Converts the coach's already-generated reply to speech with MiniMax.
 *
 * MiniMax never decides what to say on this path: Claude remains the coach,
 * and this module receives only the final text that is already visible in the
 * app. The API key stays in the Worker secret store.
 */

// api.minimax.io and api.minimax.chat are separate accounts, not mirrors: a key
// issued for one is rejected by the other as 2049 "invalid api key". This must
// stay on the same host the realtime upstream uses, or one of the two voices
// silently stops working.
const MINIMAX_T2A = "https://api.minimax.chat/v1/t2a_v2";

interface MiniMaxSpeechResponse {
    data?: {
        audio?: string;
        status?: number;
    } | null;
    base_resp?: {
        status_code?: number;
        status_msg?: string;
    };
}

export async function synthesizeSpeech(text: string, apiKey: string): Promise<Uint8Array> {
    const response = await fetch(MINIMAX_T2A, {
        method: "POST",
        headers: {
            Authorization: `Bearer ${apiKey}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            model: "speech-2.8-turbo",
            text,
            stream: false,
            language_boost: "Chinese",
            output_format: "hex",
            voice_setting: {
                voice_id: "Chinese (Mandarin)_Reliable_Executive",
                speed: 1,
                vol: 1,
                pitch: 0,
            },
            audio_setting: {
                sample_rate: 32_000,
                bitrate: 128_000,
                format: "mp3",
                channel: 1,
            },
        }),
    });

    if (!response.ok) throw new Error(`minimax_http_${response.status}`);

    const payload = (await response.json()) as MiniMaxSpeechResponse;
    if (payload.base_resp?.status_code !== 0) {
        throw new Error(`minimax_status_${payload.base_resp?.status_code ?? "unknown"}`);
    }

    const audio = payload.data?.audio;
    if (!audio || audio.length % 2 !== 0 || !/^[0-9a-f]+$/i.test(audio)) {
        throw new Error("minimax_audio_missing");
    }
    return decodeHex(audio);
}

function decodeHex(hex: string): Uint8Array {
    const bytes = new Uint8Array(hex.length / 2);
    for (let index = 0; index < bytes.length; index += 1) {
        bytes[index] = Number.parseInt(hex.slice(index * 2, index * 2 + 2), 16);
    }
    return bytes;
}
