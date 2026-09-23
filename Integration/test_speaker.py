import torch
import torchaudio
from speechbrain.inference.speaker import EncoderClassifier

print("Loading model...")
classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", savedir="tmpdir")
print("Model loaded.")
