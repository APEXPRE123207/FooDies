# Foodies 🍳✨
> *Because nobody wants to comment "RECIPE" just to get a shady DM link to a blog post about someone's grandma.*

<p align="center">
  <img src="assets/images/logo.png" alt="Foodies Logo" width="120" />
</p>

<p align="center">
  <b>Tired of saving 800 cooking reels you'll never cook? Welcome to closure.</b><br>
  <i>Foodies turns chaotic Instagram & Facebook food reels into actual, structured recipes using Ollama Cloud AI — without the life stories.</i>
</p>

---

## 🤦‍♂️ Why Does This Exist? (The Tragedy of Modern Cooking)

Let's be painfully honest for a second:

1. **The "Comment 'YES' for the recipe!" racket**: No, Chad. I'm not boosting your engagement metrics just so your automated bot can slide into my DMs with an expired bit.ly link.
2. **The 47-page essay**: You open a link looking for how many eggs to use, and you have to scroll past:
   - A memoir about autumn in Vermont.
   - 14 full-screen video ads for mattress toppers.
   - The creator’s philosophical musings on sourdough starters.
3. **The Greasy Finger Olympics**: Trying to pause a 7-second reel with flour on your knuckles while your phone screen times out and locks itself.
4. **The "Saved" Tab graveyard**: You have 412 saved reels. You made zero of them. You had toast for dinner last night.

**Foodies fixes this.** You share the reel link. AI extracts the actual food parts. You get a clean checklist. You cook. You eat. Done.

---

## 🍕 What It Actually Does

* **🤖 AI Recipe Distillation (via Ollama Cloud)**: Feeds messy social media captions to models like `gemma4:31b` or `nemotron-3-nano`. It rips out the ingredients, units, prep steps, and cooking times while throwing away the creator's sponsor plug for VPNs.
* **📱 Wakelock Cooking Mode**: Your screen stays on while you cook. Never again will you have to use your nose or an elbow to unlock your phone while handling raw chicken.
* **⚖️ Lazy-Math Ingredient Scaler**: Need to feed 6 people instead of 2? Tap once. It scales all ingredients with proper culinary fractions (`1/2`, `3/4`, etc.) so you don't have to divide 0.375 cups in your head while onions burn.
* **🔍 Multi-Token Search**: Search by whatever is currently rotting in your crisper drawer (e.g. `chicken parmesan garlic #dinner`). Finds recipes by title, ingredients, tags, or cooking method.
* **🛡️ 100% Local & Offline First**: Built on an on-device encrypted SQLite database ([Drift](https://drift.simonbinder.eu/)). We don't want your email. We don't want your cookies. If your kitchen Wi-Fi is terrible (and it is), everything still works.
* **📊 Macro & Calorie Estimation**: Automatically guesses calories, protein, carbs, and fats so you can feel either proud or moderately guilty about that skillet of heavy cream.
* **✨ Cinematic Netflix-Style UI**: Swipe through recipe flashcards with ambient aura glows and interactive checklists. If you're going to hoard recipes, at least do it in style.

---

## 🧰 Tech Stack (For the nerds inspecting our dirty laundry)

| Layer | Weapon of Choice | Why We Picked It |
|---|---|---|
| **Framework** | [Flutter](https://flutter.dev) (Dart 3.x) | Because writing the app twice is for people with too much free time. |
| **State Management** | [Riverpod](https://riverpod.dev) | Compile-time safe, testable, and doesn't make us cry like raw `InheritedWidget`. |
| **Database** | [Drift](https://drift.simonbinder.eu/) + SQLite | Fast, relational, type-safe, and stays on your phone where it belongs. |
| **Security** | `flutter_secure_storage` | Android EncryptedSharedPreferences. Your Ollama bearer token is locked down. |
| **AI Brain** | Ollama Cloud API | Runs `gemma4:31b`, `gpt-oss`, or `nemotron` in the cloud so your phone doesn't melt. |
| **Deep Link Interop** | `receive_sharing_intent` | Tap "Share to Foodies" directly from Instagram or TikTok like a civilized human. |

---

## 🚀 Getting Started (Before your water boils over)

### 1. Clone this thing
```bash
git clone https://github.com/APEXPRE123207/FooDies.git
cd FooDies
```

### 2. Grab the dependencies
```bash
flutter pub get
```

### 3. Get your free AI key
You need an Ollama Cloud key because local 30B models won't run on a budget Android phone without summoning smoke:
1. Go to [ollama.com](https://ollama.com) and create an account.
2. Head to **Settings → Keys** and copy your API key.
3. Drop it into `.env`:
   ```bash
   cp .env.example .env
   # Add your key: OLLAMA_KEY="your_key_here"
   ```
   *(Or just paste it straight into the app's onboarding screen. We won't judge).*

### 4. Fire it up
```bash
flutter run
```

---

## 🧪 Testing

We actually wrote unit tests, widget tests, and integration tests. Shocking, we know.

```bash
flutter test
```
*51 tests passing. Zero excuses.*

---

## 🙋‍♂️ Frequently Addressed Complaints (FAQ)

#### *"Why did you remove audio transcription / Groq Whisper?"*
Because Instagram gates reel video streams behind an unauthenticated anti-scraping fortress. Rather than bundling 400 MB of browser hacks and sketchy proxies, we extract the caption & metadata cleanly. If a creator didn't write the recipe and only mumbled it over trap beats, write it in manually — you have hands.

#### *"Is my diet data being sold to insurance companies?"*
No. The database lives locally on your physical device. We don't even have a telemetry server. If you eat 4 sticks of deep-fried butter, that secret dies between you, your phone, and your cardiologist.

#### *"Can I use this without an internet connection?"*
Yes! Everything you've already imported is saved locally in SQLite. The only time you need internet is when importing a new link from Instagram or running Ollama Cloud structuring.

---

## 📜 License

MIT © [APEXPRE123207](https://github.com/APEXPRE123207)

*Eat good food. Stop reading 4,000-word blog intros about autumn in Tuscany.* 🍝
