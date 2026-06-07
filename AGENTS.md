# AI Agent Instructions for Ragadl App Development

This document serves as the absolute source of truth for any AI agent or LLM assisting with the development of the **Ragadl App**. You must strictly adhere to these rules, architectural guidelines, and development philosophies before generating or modifying any code.[cite: 3]

## 1. Core Development Philosophy

- **Goal:** Ragadl App is a high-performance cross-platform application built with Flutter and Dart, designed for scraping, viewing, and managing high-fidelity image galleries.[cite: 3]
- **Flawless Execution:** The app MUST work smoothly without any bottleneck bugs. Performance regressions, UI lag, and stuttering (especially during grid scrolling and image loading) are unacceptable.[cite: 3]
- **Zero Crash Tolerance:** Improve code robustness to ensure the app does not crash under any circumstances. Always prioritize graceful degradation (e.g., showing a fallback UI or empty state) over throwing unhandled exceptions during network failures or DOM structure changes.[cite: 3]
- **No Hallucinations:** Only use existing APIs, classes, and resources within the project. If you are unsure about an existing implementation, ask Devson to fetch the file contents rather than guessing.[cite: 3]

## 2. UI / Flutter Guidelines

- **Framework:** Flutter is the exclusive UI framework.[cite: 3]
- **Design Principle:** Always consider a mobile-first approach to UI styling and layouts, ensuring the mobile screen size layout is considered first.[cite: 3]
- **Widgets & Rebuilds:** Keep widgets highly focused and modular. Prevent unnecessary rebuilds by using `const` constructors wherever possible and ensuring state updates are strictly targeted.[cite: 3]
- **State Separation:** Prefer state hoisting for UI components to keep them stateless. **Never** perform heavy calculations, HTML parsing, or file operations directly within `build()` methods.[cite: 3] Think of the main UI thread like the lead actor on a movie set-never make it wait around for the heavy lifting that should be done behind the scenes by the background crew.

## 3. Code Quality & Performance Optimization

- **Language:** Dart is the exclusive programming language.[cite: 3]
- **Null Safety & Crash Prevention:** Handle nullable types safely and exhaustively. **Never** use the bang operator (`!`) blindly. Catch specific HTTP or parsing exceptions rather than generic `Exception` types, and ensure errors are pushed to the UI state rather than silently crashing the app.[cite: 3]
- **Eliminate Bottlenecks:**[cite: 3]
  - **Network & I/O:** Always dispatch heavy DOM parsing, scraping tasks, and file reading/writing operations asynchronously. Use Isolates or `compute` for heavy data manipulation to avoid blocking the main thread.[cite: 3]
  - **Memory Management:** Be aggressive about optimizing memory. Ensure large, high-resolution 8K images are cached efficiently and disposed of properly when off-screen to prevent memory leaks.[cite: 3]
  - **Concurrency:** Ensure tasks like scraping multiple image URLs and downloading batches of files are properly parallelized with controlled concurrency (e.g., limiting max active workers).[cite: 3]
- **Canvas Constraint:** Do not give source code in the canvas. Write and apply all modifications directly inline to the core project files.

## 4. Documentation & Update Tracking

You must actively maintain the project's changelog. After every completed task, error resolution, or feature addition, you must append an entry to the `update_details.md` file.[cite: 3]

**Format and Rules for `update_details.md`:**[cite: 3]

- Do NOT read or rewrite the whole file every time. Simply append the new data at the very end of the document.[cite: 3]
- Include a Date and Time stamp for the update.[cite: 3]
- Whenever a fix, optimization, or feature is completed, you MUST document it using the following format:[cite: 3]
  - **Issue:** (Briefly describe the exact issue or bottleneck that was just solved)[cite: 3]
  - **Type:** (Specify the category: e.g., Error, Bug, UI, Performance, Architecture, Feature)[cite: 3]
  - **Solution:** (Explain how the issue was solved. Maximum 10 lines.)[cite: 3]
- After the details of the latest update, you must append exactly `---` on a new line to close out that specific session.[cite: 3]
- Do not include any conversational filler in the file.[cite: 3]

## 5. Version Control (Git) Protocol

- **Do not commit or push** any changes to the repository until explicitly being asked to do so.[cite: 3]
