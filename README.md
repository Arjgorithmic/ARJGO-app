# ARJGO — Structured Local Intelligence ✨

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-%233ECF8E.svg?style=flat&logo=supabase&logoColor=white)](https://supabase.com)
[![Local LLM](https://img.shields.io/badge/Local--AI-Qwen2--VL-blueviolet.svg?style=flat)](https://huggingface.co/Arjgorithmic/Arjgo-Qwen2-VL-2B)

**Arjgo** is a minimalist, high-performance Flutter application designed to provide structured intelligence through a specialized **Trait Pipeline System**. It utilizes local Vision-Language Models (VLM) to analyze images and return actionable, engineered insights directly on your device.

---

## 🚀 Overview

Arjgo operates as a "structured mirror," allowing you to view the world through specialized lenses (Traits):

1.  **Verdict-Based Analysis**: Instant labels like `✅ SNACKABLE` or `❌ NOT SNACKABLE` for rapid decision-making.
2.  **Identity & Trends**: Aesthetic scoring with identity labeling (e.g., `🔥 SHARP LOOK`) and trend tracking over time.
3.  **Local-First Intelligence**: Fully offline processing at `localhost:8080`, ensuring maximum privacy and zero latency.
4.  **Personal RAG Memory**: A semantic knowledge base that indexed your scans, logs, documents, and finances for context-aware chat.

---

## 🧠 Core Architecture

### 1. The Trait Pipeline
Every scan follows a strict **6-step engineered lifecycle** defined in `TraitExecutor`:
- **PreProcess**: Image optimization (640px, 90% JPEG) for edge inference.
- **Prompt Build**: Dynamic personality-driven system prompts.
- **Inference**: Interaction with the local `llama-server`.
- **Parse**: Structured field extraction (Status, Score, Suggestions) from raw output.
- **PostProcess**: Identity assignment and trend comparison.
- **Validate**: Data cleaning and cognitive load limiting (max 3 findings).

### 2. Local RAG & Vector Search
Arjgo features a robust local brain using **SQLite + Vector**:
- **Embeddings**: `all-MiniLM-L6-v2` (384d) via ONNX Runtime.
- **Semantic Sync**: Automatically indexes activity logs, scan results, and uploaded PDFs.
- **Agentic Actions**: The AI can execute background tasks like `[ACTION: CREATE_LOG]` directly from the chat.

---

## 🔬 Local AI Infrastructure

Arjgo hosts its own AI backbone for maximum stability:
- **Model**: `Qwen2-VL-2B` (quantized to Q4_K_M).
- **Server**: Native `llama-server` bridge integrated via `jniLibs` (Android) and local binary (macOS).
- **Inference API**: OpenAI-compatible Chat Completion API (`/v1/chat/completions`).

---

## 🛠 Getting Started

### 1. Requirements
- Flutter SDK (>= 3.0.0)
- Android SDK (for mobile testing)
- 2GB+ free storage (for local model assets)

### 2. Environment Setup
Create a `.env` file in the root directory:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 3. Build & Run
```bash
flutter pub get
flutter run
```

---

## 🎨 Visual Identity & Design
Arjgo follows a philosophy of **Functional Minimalism**:
- **Typography**: Exclusive use of **DM Sans** for geometric clarity.
- **Palette**: High-contrast Forest-Slate (`#2D4040`) on monochromatic backgrounds.
- **Hallmarks**: Signature *“Crafted by Arjgorithmic with pure vibes ✨”* on every key screen.

---

*Developed by Arjgorithmic. All rights reserved.*
