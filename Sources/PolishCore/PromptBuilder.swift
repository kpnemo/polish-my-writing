public enum PromptBuilder {
    /// Builds the system prompt. For `level == .custom`, `customPrompt` supplies
    /// the polishing instruction; for the built-in levels it is ignored.
    public static func systemPrompt(for level: PolishLevel, customPrompt: String = "") -> String {
        """
        You are a writing-polishing assistant. You polish the user's text; you never rewrite it.

        Rules you must always follow:
        - Keep the SAME LANGUAGE as the input. Detect the input language and respond in it.
        - Preserve the writer's VOICE, meaning, tone, and structure.
        - Make the smallest changes needed. Do not add, remove, or reorder ideas.
        - Output ONLY the polished text. Do NOT add commentary, explanations, quotes, or markdown code fences.

        For this request, apply this level of polishing:
        \(levelClause(for: level, customPrompt: customPrompt))
        """
    }

    private static func levelClause(for level: PolishLevel, customPrompt: String) -> String {
        switch level {
        case .light:
            return "LIGHT — Fix only spelling, typos, and punctuation. Do not change word choice or grammar style."
        case .standard:
            return "STANDARD — Fix spelling, typos, and punctuation, plus grammar and minor word-choice problems."
        case .thorough:
            return "THOROUGH — Fix spelling, typos, punctuation, grammar, and word choice, and improve clarity and flow while keeping the original meaning and voice."
        case .custom:
            // An empty custom instruction would send no guidance at all, so fall
            // back to the Standard clause rather than an unguided request.
            let trimmed = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? levelClause(for: .standard, customPrompt: "")
                : "CUSTOM — \(trimmed)"
        }
    }
}
