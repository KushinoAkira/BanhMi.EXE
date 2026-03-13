---
description: How to deploy the Godot game to the web (HTML5)
---

To deploy your Godot 4 game to the web, follow these steps:

### 1. Install Export Templates
Before you can export, you need the templates for the Web platform.
- Open Godot.
- Go to **Editor** > **Manage Export Templates...**
- Click **Download and Install** for the current version.

### 2. Add a Web Export Preset
- Go to **Project** > **Export...**
- Click **Add...** and select **Web**.
- If there is a warning about missing templates, make sure step 1 was successful.

### 3. C# (Mono) Specifics
> [!IMPORTANT]
> **Godot 4 versions below 4.3 do NOT support C# web exports.**
> If you see the red error message in your screenshot, it means your current Godot version or setup cannot handle C# on the web.

**Solutions:**
- **Upgrade to Godot 4.3+**: This version introduced *experimental* support for C# web exports.
- **Install .NET 8 SDK**: You must have the .NET 8 SDK installed on your system for Godot 4.3+ to export correctly.
- **Check Export Settings**: In Godot 4.3, ensure "Extensions Support" and "Thread Support" are handled according to the official documentation.
- **Fallback**: If you cannot use 4.3, the only way to have a web version is to rewrite the C# logic in **GDScript**, which we want to avoid if possible.

### 4. Exporting
- In the Export window, click **Export Project...**
- Choose a folder (e.g., `build/web/`).
- Name the file `index.html`.

### 5. Hosting (Crucial)
Godot 4 web exports require **SharedArrayBuffer**, which means your web server MUST send these headers:
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`

**Where to host?**
- **Itch.io**: Tick the "SharedArrayBuffer" support checkbox in your game's settings.
- **GitHub Pages**: Does NOT support these headers by default. You may need a service worker like [coi-serviceworker](https://github.com/gzuidhof/coi-serviceworker) to enable them.
- **Vercel/Netlify**: Can be configured via a configuration file (`vercel.json` or `_headers`).

### 6. Local Testing
To test locally, you cannot just open `index.html` in a browser. You need a local server.
- You can use the **"Remote Debug"** button in Godot's export window to launch a local server and test immediately.
