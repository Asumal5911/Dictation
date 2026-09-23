import os
import time
import json
import psutil
import mlx_whisper
import jiwer
import argparse
from pathlib import Path

# Important terms we do not want the model to miss or alter
CRITICAL_TERMS = ["not", "never", "cannot", "no", "plato", "socrates", "epistemology", "dijkstra", "recursion", "does not", "should not"]

def load_ground_truth(file_path):
    if not os.path.exists(file_path):
        return None
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read().strip()

def analyze_critical_errors(reference, hypothesis):
    ref_lower = reference.lower()
    hyp_lower = hypothesis.lower()
    
    errors = {}
    for term in CRITICAL_TERMS:
        ref_count = ref_lower.count(term)
        hyp_count = hyp_lower.count(term)
        if ref_count != hyp_count:
            errors[term] = {"expected": ref_count, "found": hyp_count}
            
    return errors

def benchmark_model(audio_path, model_path, ground_truth):
    print(f"\n--- Testing {model_path} on {audio_path} ---")
    
    start_time = time.time()
    
    # Process memory before
    process = psutil.Process(os.getpid())
    mem_before = process.memory_info().rss / (1024 * 1024)
    
    # Run inference
    result = mlx_whisper.transcribe(str(audio_path), path_or_hf_repo=model_path)
    
    mem_after = process.memory_info().rss / (1024 * 1024)
    end_time = time.time()
    
    inference_time = end_time - start_time
    transcript = result["text"].strip()
    
    print(f"Inference Time: {inference_time:.2f}s")
    print(f"Memory Diff: {mem_after - mem_before:.2f} MB")
    
    metrics = {
        "model": model_path,
        "inference_time_sec": inference_time,
        "transcript": transcript
    }
    
    if ground_truth:
        wer = jiwer.wer(ground_truth, transcript)
        critical_errors = analyze_critical_errors(ground_truth, transcript)
        
        metrics["wer"] = wer
        metrics["critical_errors"] = critical_errors
        
        print(f"Word Error Rate (WER): {wer:.4f}")
        if critical_errors:
            print("CRITICAL ERRORS FOUND:")
            for term, counts in critical_errors.items():
                print(f"  - '{term}': Expected {counts['expected']}, Found {counts['found']}")
        else:
            print("Zero critical errors detected.")
            
    return metrics

def main():
    parser = argparse.ArgumentParser(description="Benchmark Whisper models for Mac Local Dictation")
    parser.add_argument("--audio-dir", type=str, default="./samples", help="Directory containing audio samples and corresponding .txt ground truth files")
    args = parser.parse_args()
    
    audio_dir = Path(args.audio_dir)
    if not audio_dir.exists():
        print(f"Creating sample directory at {audio_dir}. Please place .wav/.flac and corresponding .txt files here.")
        audio_dir.mkdir(parents=True)
        return

    models_to_test = [
        "mlx-community/whisper-large-v3-mlx",
        "mlx-community/whisper-large-v3-turbo"
    ]
    
    results = {}
    
    audio_files = list(audio_dir.glob("*.wav")) + list(audio_dir.glob("*.flac"))
    
    if not audio_files:
        print("No audio files found. Please add .wav or .flac files to the samples directory.")
        return
        
    for audio_file in audio_files:
        gt_file = audio_file.with_suffix('.txt')
        ground_truth = load_ground_truth(gt_file)
        
        if ground_truth is None:
            print(f"Warning: No ground truth .txt file found for {audio_file.name}. WER will not be calculated.")
            
        file_results = []
        for model in models_to_test:
            res = benchmark_model(audio_file, model, ground_truth)
            file_results.append(res)
            
        results[audio_file.name] = file_results
        
    with open("benchmark_results.json", "w") as f:
        json.dump(results, f, indent=4)
        
    print("\nBenchmarking complete. Results saved to benchmark_results.json")

if __name__ == "__main__":
    main()
