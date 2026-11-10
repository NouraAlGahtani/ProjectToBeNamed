# Yusr iOS Xcode project

Open **Yusr.xcodeproj** in Xcode on your Mac. Select an iPhone simulator and press Command-R. No need to create another project or import Swift files.

## AI backend
Open Terminal, navigate to `backend`, activate/create a virtual environment, install `requirements.txt`, run `ollama pull qwen3:4b`, then `uvicorn main:app --host 127.0.0.1 --port 8000`. Ollama must be running. The iOS Simulator calls this local backend.

## Limitations
The code has not been built on macOS/Xcode in this environment. Microphone and speech recognition require permission and may work better on a real iPhone. Saudi XTTS requires separate model setup; the app falls back to Apple speech. No validated stuttering analysis or recording replay yet. HTTP exceptions are for LOCAL DEVELOPMENT ONLY: use HTTPS and restrict App Transport Security before distributing.
