
import os
import logging
from typing import Literal

from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from starlette.concurrency import run_in_threadpool
import azure.cognitiveservices.speech as speechsdk
from pydantic import BaseModel, Field
import httpx

from cleaning import clean_reply

log = logging.getLogger("uvicorn.error")

OLLAMA_URL = os.getenv(
    "OLLAMA_URL", "http://127.0.0.1:11434"
)
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen3:8b")

FALLBACK_REPLY = (
    "Sorry, could you say that once more? Take your time."
)

app = FastAPI(title="Yusr English Conversation API")


class Message(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=5000)


class ChatRequest(BaseModel):
    mode: str
    messages: list[Message] = Field(min_length=1, max_length=50)


SYSTEM = """You are a friendly person participating in an English conversation practice scenario.

You are speaking directly to the customer or conversation partner.
Stay in character throughout the conversation.

IMPORTANT:
- Output ONLY the words your character would actually say.
- Never describe the scenario, user, instructions, or your reasoning.
- Never explain how you will respond.
- Keep each response to one or two short sentences.
- Ask at most one question.
- Be patient, supportive, and natural.
- Never criticize stuttering, pauses, or speech speed.
- Do not diagnose or offer medical treatment.

Example:
Customer: Hello, I would like to order a coffee, please.
Your reply: Of course! What kind of coffee would you like?
"""


@app.get("/health")
async def health():
    try:
        async with httpx.AsyncClient(timeout=3) as client:
            response = await client.get(
                OLLAMA_URL + "/api/tags"
            )
            available = response.status_code == 200
    except httpx.HTTPError:
        available = False

    return {
        "status": "ok",
        "ollama_available": available,
        "model": OLLAMA_MODEL,
        "azure_speech_configured": bool(
            os.getenv("AZURE_SPEECH_KEY")
            and os.getenv("AZURE_SPEECH_REGION")
        ),
    }


async def ask_ollama(messages: list[dict]) -> str:
    payload = {
        "model": OLLAMA_MODEL,
        "messages": messages,
        "stream": False,
        "think": False,
        "options": {
            "temperature": 0.3,
            "num_predict": 120,
        },
    }

    async with httpx.AsyncClient(timeout=180) as client:
        r = await client.post(
            OLLAMA_URL + "/api/chat",
            json=payload,
        )
        r.raise_for_status()

    message = r.json()["message"]

    if message.get("thinking"):
        log.info(
            "Ollama returned reasoning; ignoring it."
        )

    return message.get("content", "")


@app.post("/chat")
async def chat(body: ChatRequest):
    system = (
        SYSTEM
        + "\nConversation scenario: "
        + body.mode
        + "\n/no_think"
    )

    history = [m.model_dump() for m in body.messages]

    base = [
        {"role": "system", "content": system},
        *history,
    ]

    nudge = {
        "role": "system",
        "content": (
            "Reply with ONLY the exact words you would "
            "say out loud, in one or two short sentences. "
            "No analysis, no planning, no mention of the user."
        ),
    }

    try:
        for attempt in range(2):
            raw = await ask_ollama(
                base if attempt == 0 else base + [nudge]
            )

            reply, ok = clean_reply(raw)

            if ok:
                return {"reply": reply}

            log.warning(
                "Rejected model output (attempt %d): %r",
                attempt + 1,
                raw[:200],
            )

    except (httpx.HTTPError, KeyError, IndexError) as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                "Ollama unavailable. Run: ollama pull "
                + OLLAMA_MODEL
            ),
        ) from exc

    return {"reply": FALLBACK_REPLY}


class SpeechRequest(BaseModel):
    text: str = Field(min_length=1, max_length=1200)


@app.post("/speak")
async def speak(body: SpeechRequest):
    """Generate Andrew Dragon HD speech as WAV audio."""

    key = os.getenv("AZURE_SPEECH_KEY")
    region = os.getenv("AZURE_SPEECH_REGION")

    if not key or not region:
        raise HTTPException(
            status_code=503,
            detail="Azure Speech credentials are not configured",
        )

    def synthesize() -> bytes:
        config = speechsdk.SpeechConfig(
            subscription=key,
            region=region,
        )

        config.speech_synthesis_voice_name = (
            "en-US-Andrew:DragonHDLatestNeural"
        )

        config.set_speech_synthesis_output_format(
            speechsdk.SpeechSynthesisOutputFormat
            .Riff24Khz16BitMonoPcm
        )

        synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=config,
            audio_config=None,
        )

        result = synthesizer.speak_text_async(
            body.text
        ).get()

        if (
            result.reason
            != speechsdk.ResultReason.SynthesizingAudioCompleted
        ):
            if result.reason == speechsdk.ResultReason.Canceled:
                d = result.cancellation_details

                log.error(
                    "Azure synthesis canceled: "
                    "reason=%s code=%s details=%s",
                    d.reason,
                    getattr(d, "error_code", None),
                    d.error_details,
                )

            raise RuntimeError(
                "Azure speech synthesis was not completed"
            )

        if not result.audio_data:
            raise RuntimeError(
                "Azure returned no audio"
            )

        return result.audio_data

    try:
        audio = await run_in_threadpool(synthesize)

    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail="Azure speech synthesis failed",
        ) from exc

    return Response(
        content=audio,
        media_type="audio/wav",
    )
