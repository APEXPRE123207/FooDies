# Foodies 🍳✨

> Turn Instagram & Facebook cooking reels into clean, searchable, offline-ready recipes powered by Ollama Cloud AI.

![Foodies Logo](assets/images/logo.png)

## 🌟 Highlights

- **Cinematic Flashcard Feed**: Swipe through an infinite, interactive feed of saved recipes with cook times, servings, calorie estimates, and cuisine tags.
- **AI-Powered Extraction**: Transforms unstructured social captions and transcripts into clean ingredients, precise measurements, and numbered preparation steps using Ollama Cloud.
- **Local-First & Privacy Guaranteed**: All recipes, steps, ingredients, and tags are saved to an on-device encrypted SQLite database. Zero external user tracking, zero account requirement.
- **Smart Servings Scaling**: Instantly scale ingredient quantities up or down with automatic culinary fraction formatting (e.g. `1/2`, `3/4`).
- **Nutrition Estimation**: Automatic calorie and macronutrient breakdown (creator-stated or algorithmic composition estimate).
- **Interactive Checklist**: Mark ingredients off as you cook with haptic feedback.
- **Offline Ready**: Full access to your recipe library and instructions anytime, even without an internet connection.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Local Storage**: [Drift](https://drift.simonbinder.eu/) + SQLite with foreign keys & migrations
- **Secure Key Storage**: `flutter_secure_storage` (Android EncryptedSharedPreferences)
- **AI Engine**: Ollama Cloud API (`gemma4:31b`, `nemotron-3-nano`, `gpt-oss:20b`)
- **Sharing & Interop**: Android System Share Intent Receiver

---

## 🚀 Getting Started

### 1. Clone the repository
```bash
git clone https://github.com/APEXPRE123207/FooDies.git
cd FooDies
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure API Key
Copy the example environment configuration:
```bash
cp .env.example .env
```
Add your free Ollama Cloud API key from [ollama.com/settings/keys](https://ollama.com/settings/keys):
```env
OLLAMA_KEY="your_api_key_here"
```

### 4. Run the app
```bash
flutter run
```

---

## 🧪 Testing

Run unit, integration, and UI widget tests:
```bash
flutter test
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
