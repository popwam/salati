# AI.js Religious Domain Classifier Report

## Overview

The AI worker now includes a multi-layered religious domain classifier to ensure that out-of-scope or generic questions are handled gracefully without consuming expensive AI generation tokens or providing irrelevant answers.

## Classifier Flow

1.  **Gemini Classifier (Primary)**: If `GEMINI_API_KEY` is configured, the worker sends the user message to Gemini with a strict classification prompt. It returns a JSON object identifying if the message is religious, the specific sub-domain (Quran, Hadith, etc.), and a confidence score.
2.  **Workers AI Fallback**: If Gemini fails or is not configured, the worker falls back to Cloudflare Workers AI (Llama 3.1) for a similar classification task.
3.  **Deterministic Fallback (Local)**: If both AI layers fail, the worker uses a keyword-based deterministic match. This layer has been improved to detect religious Arabic terms, common typos (e.g., "الثيام" for "القيام"), and obvious out-of-scope technical/commercial terms.

## Rejection & Clarification

-   **Out of Scope**: If a message is identified as non-religious with high confidence, the worker returns a fixed "out-of-scope" response explaining that it is specialized for Islamic topics.
-   **Ambiguous**: If the domain is unclear or AI confidence is low, the worker returns a clarification request asking the user to provide more religious context.

## Manual Test Cases

| Prompt | Result | Sub-Domain |
| :--- | :--- | :--- |
| ايه فيها الجنه والنار | Allowed | quran |
| صلاه الثيام | Allowed | prayer |
| حديث النيه | Allowed | hadith |
| انا مش منتظم في الصلاة | Allowed | prayer |
| اعمل كود Flutter | Rejected | out_of_scope |
| سعر الدولار كام | Rejected | out_of_scope |
| هل يجوز كذا | Allowed | fiqh |
| ممكن تساعدني؟ | Ambiguous | clarify |

## Implementation Details

-   **Location**: `chatCore` in `ai.js` handles the initial gating.
-   **Helpers**: Extracted logic into `buildDomainGateResponse`, `defaultOutOfScopeByLang`, and `defaultReligiousClarificationByLang`.
-   **Safety**: Replaced potentially malformed URL generation and added strict validation for AI JSON responses.

## Future Improvements

1.  **Firebase Auth Integration**: Move identity and quota management from spoofable headers to trusted Firebase ID token verification.
2.  **Extended Fiqh Grounding**: Integrate a trusted Fiqh corpus to provide source-backed guidance for general "halal/haram" questions.
3.  **Slang Refinement**: Continue updating the deterministic keyword list as common user slang and regional typos are identified in logs.

## Code Integrity

Ran `node --check ai.js` to ensure syntax correctness.

---
*Status: Refactored and Repaired*
*Version: v17-domain-gate-v2*