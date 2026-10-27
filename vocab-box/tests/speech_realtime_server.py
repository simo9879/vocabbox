"""Loopback WebSocket fixture for the realtime transcription adapter."""

import asyncio
import base64
import json
import sys
from urllib.parse import parse_qs, urlsplit

import websockets


async def transcribe(socket, path):
    query = parse_qs(urlsplit(path).query)
    if (
        socket.request_headers.get("xi-api-key") != "fixture-key"
        or "token" in query
        or query.get("commit_strategy") != ["manual"]
    ):
        await socket.close(code=1008)
        return
    await socket.send(json.dumps({"message_type": "session_started", "config": {"audio_format": "pcm_16000"}}))
    chunks = []
    async for payload in socket:
        message = json.loads(payload)
        if message.get("message_type") != "input_audio_chunk" or message.get("sample_rate") != 16000:
            await socket.send(json.dumps({"message_type": "input_error", "error": "Bad audio format"}))
            return
        chunks.append(base64.b64decode(message["audio_base_64"], validate=True))
        if message.get("commit"):
            text = "Where are the bananas?" if len(chunks) >= 2 and sum(map(len, chunks)) == 4800 else ""
            await socket.send(json.dumps({"message_type": "committed_transcript", "text": text}))
            await asyncio.sleep(0.2)
            return
        await socket.send(json.dumps({"message_type": "partial_transcript", "text": "Where are"}))


async def main(ws_port):
    async with websockets.serve(transcribe, "127.0.0.1", ws_port):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main(int(sys.argv[1])))
