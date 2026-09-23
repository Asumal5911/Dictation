import os
import time
import json
import glob
from pathlib import Path
from vad import has_speech
from transcriber import create_logical_window, transcribe_chunk
from deduplicator import merge_overlapping_text

class ProcessingManager:
    def __init__(self, watch_dir):
        self.watch_dir = Path(watch_dir)
        self.processed_chunks = set()
        self.session_states = {} # map session_dir -> { 'last_chunk': path, 'last_transcript': text }
        
    def scan_sessions(self):
        """Scans for active sessions and reads their journals."""
        session_dirs = glob.glob(str(self.watch_dir / "MacDictation_Session_*"))
        
        for session_dir in session_dirs:
            journal_path = os.path.join(session_dir, "events.journal")
            if not os.path.exists(journal_path):
                continue
                
            if session_dir not in self.session_states:
                self.session_states[session_dir] = {
                    'last_chunk': None,
                    'last_transcript': ""
                }
                
            self.process_journal(session_dir, journal_path)

    def process_journal(self, session_dir, journal_path):
        """Reads the journal, finds un-transcribed chunks, and queues them."""
        with open(journal_path, 'r') as f:
            lines = f.readlines()
            
        for line in lines:
            if not line.strip():
                continue
            try:
                event = json.loads(line)
                if event.get("type") == "CHUNK_COMMITTED":
                    chunk_filename = event.get("file")
                    chunk_path = os.path.join(session_dir, chunk_filename)
                    
                    if chunk_path not in self.processed_chunks and os.path.exists(chunk_path):
                        self.process_chunk(session_dir, chunk_path)
                        
            except json.JSONDecodeError:
                continue

    def process_chunk(self, session_dir, chunk_path):
        print(f"\nProcessing newly committed chunk: {chunk_path}")
        state = self.session_states[session_dir]
        
        # 1. VAD Check
        if not has_speech(chunk_path):
            print(" -> No speech detected. Skipping transcription.")
            self.processed_chunks.add(chunk_path)
            state['last_chunk'] = chunk_path
            # We don't change last_transcript because there was no speech.
            return
            
        # 2. Logical Overlap Creation
        prev_chunk = state['last_chunk']
        window_path = create_logical_window(prev_chunk, chunk_path, overlap_seconds=10)
        
        # 3. Transcribe with context
        print(" -> Transcribing...")
        # Provide previous transcript as prompt context to help Whisper
        prompt = state['last_transcript'][-500:] if state['last_transcript'] else None
        
        raw_text = transcribe_chunk(window_path, initial_prompt=prompt)
        
        # Cleanup temp logical window file
        if window_path != chunk_path and os.path.exists(window_path):
            os.remove(window_path)
            
        # 4. Deduplicate/Merge text
        print(" -> Deduplicating and merging...")
        merged_text = merge_overlapping_text(state['last_transcript'], raw_text)
        
        # 5. Append to transcript file
        transcript_file = os.path.join(session_dir, "raw_transcript.md")
        with open(transcript_file, "w", encoding="utf-8") as f:
            f.write(merged_text)
            
        print(f" -> Transcript updated in {transcript_file}")
        
        # Update state
        self.processed_chunks.add(chunk_path)
        state['last_chunk'] = chunk_path
        state['last_transcript'] = merged_text

    def run(self):
        print(f"Starting Processing Manager. Watching {self.watch_dir} for sessions...")
        while True:
            self.scan_sessions()
            time.sleep(2) # Poll every 2 seconds

if __name__ == "__main__":
    docs_dir = os.path.expanduser("~/Documents")
    manager = ProcessingManager(watch_dir=docs_dir)
    manager.run()
