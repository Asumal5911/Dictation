import Foundation
import FoundationModels

/// Turns raw speech recognition into faithful, readable plain-text notes.
/// A fresh session is used for every dictation so one note cannot leak context
/// into the next one.
final class ContextualNoteFormatter: @unchecked Sendable {
    private func logDebug(_ msg: String) {
        let url = URL(fileURLWithPath: "/tmp/dictation_debug.txt")
        let text = "[\(Date())] \(msg)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            if let data = text.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func format(_ rawText: String, completion: @escaping (String) -> Void) {
        let source = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            completion("")
            return
        }

        guard #available(macOS 26.0, *) else {
            logDebug("macOS 26.0 not available")
            completion(basicCleanup(source))
            return
        }

        let model = SystemLanguageModel(
            useCase: .general,
            guardrails: .permissiveContentTransformations
        )
        guard model.isAvailable else {
            logDebug("model.isAvailable is false")
            print("ℹ️ Apple Intelligence is unavailable; using basic punctuation cleanup")
            completion(basicCleanup(source))
            return
        }

        var completed = false
        let lock = NSLock()
        func dispatchOnce(_ text: String, _ reason: String = "") {
            lock.lock()
            defer { lock.unlock() }
            guard !completed else { return }
            completed = true
            if !reason.isEmpty { logDebug("Returning because: \(reason)") }
            DispatchQueue.main.async { completion(text) }
        }

        // Safety timeout: if Apple Intelligence stalls for 180 seconds, dispatch basic cleanup immediately
        DispatchQueue.global().asyncAfter(deadline: .now() + 180) {
            dispatchOnce(self.basicCleanup(source), "timeout")
        }

        Task {
            let words = source.split(whereSeparator: { $0.isWhitespace })
            let chunkSize = 400
            var chunks: [String] = []
            
            for i in stride(from: 0, to: words.count, by: chunkSize) {
                let end = min(i + chunkSize, words.count)
                let chunk = words[i..<end].joined(separator: " ")
                chunks.append(chunk)
            }

            var formattedChunks: [String] = []
            
            for (idx, chunk) in chunks.enumerated() {
                do {
                    logDebug("Starting chunk \(idx), word count: \(chunk.split(separator: " ").count)")
                    let session = LanguageModelSession(
                        model: model,
                        instructions: Self.editorInstructions
                    )
                    let chunkWordCount = chunk.split(whereSeparator: { $0.isWhitespace }).count
                    let tokenLimit = min(2_048, max(256, chunkWordCount * 4))
                    let response = try await session.respond(
                        to: "RAW TRANSCRIPT:\n\(chunk)\n\nReturn only the finished notes.",
                        options: GenerationOptions(
                            sampling: .greedy,
                            maximumResponseTokens: tokenLimit
                        )
                    )
                    let candidate = self.emphasizeExplicitTakeaway(in: self.sanitize(response.content))
                    let isF = self.isFaithful(candidate, to: chunk)
                    logDebug("Chunk \(idx) isFaithful: \(isF)")
                    let result = isF ? candidate : self.basicCleanup(chunk)
                    if !isF {
                        logDebug("Fidelity check failed. Candidate length: \(candidate.count), Chunk length: \(chunk.count)")
                        logDebug("Candidate:\n\(candidate)")
                    }
                    formattedChunks.append(result)
                } catch {
                    logDebug("Chunk \(idx) error: \(error.localizedDescription)")
                    formattedChunks.append(self.basicCleanup(chunk))
                }
            }
            
            let finalResult = formattedChunks.joined(separator: "\n\n")
            dispatchOnce(finalResult, "success")
        }
    }

    private static let editorInstructions = """
    You are the final editing stage of a private, on-device English dictation app for live lecture notes.

    Transform the raw speech transcript into clear, concise, highly readable notes while preserving the speaker's meaning exactly.

    Rules:
    - FIX all grammatical errors, broken sentences, and obvious speech-to-text artifacts so the sentences make complete sense.
    - Resolve an obvious homophone or misheard word only when the surrounding context makes the correction unambiguous.
    - Never invent, infer, summarize away, or add facts, names, dates, numbers, examples, conclusions, or opinions.
    - Preserve technical terms, quantities, qualifications, uncertainty, and every negation.
    - Use short paragraphs when the topic or idea changes.
    - Add short Markdown headings (###) when a new topic starts or when it's clear from the transcript. You may use bold text for emphasis.
    - Use a numbered list only for an actual sequence, ranking, procedure, or explicitly ordered set.
    - Use bullet characters (•) only for a genuine unordered group of related points.
    - When a central takeaway is explicitly present, put it on its own line beginning with "KEY POINT: ". Do not manufacture a takeaway.
    - Do not force a heading or list onto a short ordinary sentence.
    - Return only the finished notes. Do not explain your work and do not use code fences.
    """

    private func sanitize(_ text: String) -> String {
        var output = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.hasPrefix("```") {
            output = output.replacingOccurrences(
                of: #"^```(?:text)?\s*|\s*```$"#,
                with: "",
                options: .regularExpression
            )
            output = output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return output
    }

    private func emphasizeExplicitTakeaway(in text: String) -> String {
        let normalized = text.replacingOccurrences(
            of: #"(?im)^[ \t]*(?:the[ \t]+)?key point(?:[ \t]+is)?[ \t]*[:\-]?[ \t]*"#,
            with: "KEY POINT: ",
            options: .regularExpression
        )
        return normalized.components(separatedBy: "\n").map { line in
            let prefix = "KEY POINT: "
            guard line.hasPrefix(prefix), line.count > prefix.count else { return line }
            var remainder = String(line.dropFirst(prefix.count))
            remainder.replaceSubrange(
                remainder.startIndex...remainder.startIndex,
                with: String(remainder[remainder.startIndex]).uppercased()
            )
            return prefix + remainder
        }.joined(separator: "\n")
    }

    private func isFaithful(_ candidate: String, to source: String) -> Bool {
        guard !candidate.isEmpty else { return false }

        let sourceWords = source.split(whereSeparator: { $0.isWhitespace }).count
        let candidateWords = candidate.split(whereSeparator: { $0.isWhitespace }).count
        
        // Relaxed fidelity check to allow formatting (lists, paragraphs), grammar fixes, and removal of conversational filler
        // Spoken lectures can easily reduce in word count by 50-70% when properly formatted into concise notes.
        guard candidateWords >= max(1, Int(Double(sourceWords) * 0.25)),
              candidateWords <= Int(Double(sourceWords) * 1.60) + 20 else {
            return false
        }

        return true
    }

    private func basicCleanup(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return cleaned }

        cleaned.replaceSubrange(
            cleaned.startIndex...cleaned.startIndex,
            with: String(cleaned[cleaned.startIndex]).uppercased()
        )
        if let last = cleaned.last, !".!?".contains(last) {
            cleaned.append(".")
        }
        return cleaned
    }
}
