import torch
import torchaudio

# Load Silero VAD globally to avoid reloading per chunk
model, utils = torch.hub.load(repo_or_dir='snakers4/silero-vad',
                              model='silero_vad',
                              force_reload=False,
                              trust_repo=True)

(get_speech_timestamps, save_audio, read_audio, VADIterator, collect_chunks) = utils

def has_speech(audio_path, threshold=0.5):
    """
    Reads an audio file and returns True if it contains speech above the confidence threshold.
    Silero VAD expects 16kHz audio.
    """
    try:
        wav = read_audio(str(audio_path), sampling_rate=16000)
        # get_speech_timestamps returns a list of dicts: [{'start': 123, 'end': 456}]
        speech_timestamps = get_speech_timestamps(wav, model, sampling_rate=16000, threshold=threshold)
        
        return len(speech_timestamps) > 0
    except Exception as e:
        print(f"VAD Error on {audio_path}: {e}")
        # If VAD fails for some reason (e.g. wrong format), default to True so we don't drop audio!
        # The Core Invariant: "Never drop text merely because a heuristic..."
        return True

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        print(f"Speech Detected: {has_speech(sys.argv[1])}")
