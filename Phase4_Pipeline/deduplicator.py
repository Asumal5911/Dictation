import difflib
import re

def normalize_text(text):
    """Normalize text for alignment by lowering case and removing punctuation."""
    text = text.lower()
    text = re.sub(r'[^\w\s]', '', text)
    return text.strip()

def merge_overlapping_text(previous_text, current_text, overlap_threshold_words=3):
    """
    Merges two sequential transcripts that share an overlapping audio region.
    Uses SequenceMatcher to find the exact suffix-prefix textual overlap.
    """
    if not previous_text:
        return current_text
    if not current_text:
        return previous_text
        
    # We only care about the end of the previous text and the start of the current.
    # Take the last 30 words of previous, and first 30 of current for alignment
    prev_words = previous_text.split()
    curr_words = current_text.split()
    
    tail_len = min(30, len(prev_words))
    head_len = min(30, len(curr_words))
    
    prev_tail = " ".join(prev_words[-tail_len:])
    curr_head = " ".join(curr_words[:head_len])
    
    norm_tail = normalize_text(prev_tail)
    norm_head = normalize_text(curr_head)
    
    matcher = difflib.SequenceMatcher(None, norm_tail.split(), norm_head.split())
    match = matcher.find_longest_match(0, len(norm_tail.split()), 0, len(norm_head.split()))
    
    if match.size >= overlap_threshold_words:
        # A significant overlap was found!
        # We need to splice the actual original (un-normalized) strings.
        
        # Calculate how many words into the original strings the match corresponds to
        # (Since normalization preserves word count in most cases)
        overlap_start_in_tail = match.a
        overlap_size = match.size
        
        # We drop the overlapping part from the current_text.
        # How many words to drop from current_text? match.b + match.size
        drop_curr_words_count = match.b + match.size
        
        remaining_current_words = curr_words[drop_curr_words_count:]
        
        # Join the full previous text with the non-overlapping remainder of the current text
        return previous_text + " " + " ".join(remaining_current_words)
        
    # If no significant overlap is found, it implies silence or a hard cut with no duplicated words.
    return previous_text + " " + current_text

if __name__ == "__main__":
    # Test deduplication
    prev = "And so Plato describes the Form of the Good as the ultimate"
    curr = "Form of the Good as the ultimate truth that illuminates all other forms."
    
    merged = merge_overlapping_text(prev, curr)
    print("Merged:", merged)
