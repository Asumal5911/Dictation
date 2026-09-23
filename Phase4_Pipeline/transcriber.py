import mlx_whisper
import soundfile as sf
import numpy as np
import os
import tempfile

def create_logical_window(prev_audio_path, curr_audio_path, overlap_seconds=10):
    """
    Reads the tail of prev_audio_path and prepends it to curr_audio_path.
    Returns the path to a temporary WAV file containing the logically overlapped audio,
    or just the current audio path if no overlap is needed/possible.
    """
    if not prev_audio_path or not os.path.exists(prev_audio_path):
        return curr_audio_path
        
    try:
        prev_data, prev_sr = sf.read(prev_audio_path)
        curr_data, curr_sr = sf.read(curr_audio_path)
        
        if prev_sr != curr_sr:
            return curr_audio_path # Sample rate mismatch, fallback to current only
            
        # Calculate samples for overlap
        overlap_samples = int(overlap_seconds * prev_sr)
        
        if len(prev_data) < overlap_samples:
            tail_data = prev_data
        else:
            tail_data = prev_data[-overlap_samples:]
            
        merged_data = np.concatenate((tail_data, curr_data))
        
        # Save to temp file
        temp_file = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        sf.write(temp_file.name, merged_data, curr_sr)
        
        return temp_file.name
    except Exception as e:
        print(f"Error creating logical window: {e}")
        return curr_audio_path


def transcribe_chunk(audio_path, initial_prompt=None, model_path="mlx-community/whisper-large-v3-mlx"):
    """
    Transcribes the audio using mlx-whisper.
    Passes initial_prompt to provide context from the previous chunk.
    """
    try:
        # mlx-whisper supports passing an initial prompt string
        result = mlx_whisper.transcribe(
            str(audio_path),
            path_or_hf_repo=model_path,
            initial_prompt=initial_prompt
        )
        return result["text"].strip()
    except Exception as e:
        print(f"Transcription error: {e}")
        return ""
