import requests
import json
import difflib

# Ollama local endpoint
OLLAMA_API_URL = "http://localhost:11434/api/generate"

def format_transcript(raw_text, course_vocabulary="", model="llama3.1"):
    """
    Sends the raw verbatim transcript to a local Ollama model to format it strictly.
    Includes course_vocabulary to ensure technical terms are respected.
    """
    
    vocab_instruction = ""
    if course_vocabulary:
        vocab_instruction = f"""
COURSE VOCABULARY:
The following technical terms and names appear in this lecture. You MUST preserve their exact spelling and casing:
{course_vocabulary}
"""

    system_prompt = f"""You are a strict formatting engine for university lectures.
Your ONLY job is to take the raw, verbatim transcript and format it into readable paragraphs, sentences with proper capitalization, and punctuation.

CRITICAL FIDELITY RULES:
1. DO NOT summarize, compress, or paraphrase the text in any way.
2. DO NOT alter, remove, or "correct" any negative qualifiers (e.g., "not", "never", "cannot").
3. DO NOT change any numbers or quantities.
4. DO NOT omit sentences, even if they are conversational tangents.
5. You may format obvious spoken lists into bullet points.
{vocab_instruction}

If the speaker says "The sky is not blue", you must output "The sky is not blue."
If you remove the word "not", you have failed your core directive.

Raw Transcript to format:
"""

    payload = {
        "model": model,
        "prompt": system_prompt + raw_text,
        "stream": False,
        "options": {
            "temperature": 0.0 # Strict determinism, no creative hallucinations
        }
    }
    
    try:
        response = requests.post(OLLAMA_API_URL, json=payload)
        response.raise_for_status()
        return response.json().get("response", "").strip()
    except requests.exceptions.RequestException as e:
        print(f"Ollama connection error: {e}")
        return raw_text # Fallback to raw text if formatter fails (Core Invariant)


def verify_critical_fidelity(original, formatted, check_terms):
    """
    Validates that the formatter did not destroy critical terms or negations.
    Returns a list of fidelity violations.
    """
    orig_lower = original.lower()
    fmt_lower = formatted.lower()
    
    violations = []
    
    for term in check_terms:
        # Check raw counts (simplistic but effective for negations/numbers)
        orig_count = orig_lower.count(term.lower())
        fmt_count = fmt_lower.count(term.lower())
        
        if orig_count != fmt_count:
            violations.append(f"VIOLATION: '{term}' appeared {orig_count} times in raw, but {fmt_count} times in formatted.")
            
    return violations


# --- Regression Test Suite ---

if __name__ == "__main__":
    
    print("--- Phase 6: Strict Fidelity Formatting Test ---")
    
    # Test cases simulating typical LLM failure modes (dropping negations, changing numbers)
    test_cases = [
        {
            "name": "Negation Preservation",
            "raw": "so the algorithm does not scale well past o of n squared because you never want to do that in production",
            "vocab": "",
            "checks": ["does not", "never", "o of n squared"]
        },
        {
            "name": "Technical Vocabulary",
            "raw": "plato describes the form of the good as being completely separate from the physical world unlike Aristotle's view",
            "vocab": "Plato, Form of the Good, Aristotle",
            "checks": ["plato", "form of the good", "aristotle"]
        },
        {
            "name": "Number Accuracy",
            "raw": "we administered exactly forty two milligrams to the 17 patients",
            "vocab": "",
            "checks": ["forty two", "17"]
        }
    ]
    
    for case in test_cases:
        print(f"\nRunning Test: {case['name']}")
        print(f"Raw: {case['raw']}")
        
        # In a real environment with Ollama running, this would call the model.
        # formatted = format_transcript(case['raw'], case['vocab'])
        
        # For POC, we simulate the LLM's perfect response (what it SHOULD output)
        if case['name'] == "Negation Preservation":
            simulated_output = "So, the algorithm does not scale well past O of N squared, because you never want to do that in production."
        elif case['name'] == "Technical Vocabulary":
            simulated_output = "Plato describes the Form of the Good as being completely separate from the physical world, unlike Aristotle's view."
        else:
            simulated_output = "We administered exactly forty-two milligrams to the 17 patients."
            
        print(f"Formatted: {simulated_output}")
        
        violations = verify_critical_fidelity(case['raw'], simulated_output, case['checks'])
        
        if not violations:
            print("Status: PASS (Zero fidelity violations)")
        else:
            print("Status: FAIL")
            for v in violations:
                print("  " + v)
