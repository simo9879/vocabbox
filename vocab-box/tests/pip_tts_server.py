"""Loopback ElevenLabs TTS fixture; it reads a local test MP3, never an API key."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sys
import time


class Handler(BaseHTTPRequestHandler):
    audio = b""

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        try:
            request = json.loads(raw)
            valid = (
                self.path.startswith("/v1/text-to-speech/pFZP5JQG7iQjIQuC4Bku?output_format=mp3_44100_128")
                and self.headers.get("xi-api-key") == "fixture-elevenlabs-key"
                and self.headers.get("Content-Type") == "application/json"
                and request == {"text": "Great answer!", "model_id": "eleven_v4"}
            )
        except (TypeError, ValueError):
            valid = False
        if not valid:
            self.respond(400, b"bad request", "text/plain")
        elif self.path.endswith("&slow=1"):
            time.sleep(0.6)
            self.respond(200, self.audio, "audio/mpeg")
        elif self.path.endswith("&bad=1"):
            self.respond(200, b"not mp3", "application/json")
        elif self.path.endswith("&error=1"):
            detail = {"detail": {"code": "model_not_supported", "message": "This voice cannot use eleven_v4."}}
            self.respond(422, json.dumps(detail).encode(), "application/json")
        else:
            self.respond(200, self.audio, "audio/mpeg")

    def respond(self, status, body, content_type):
        try:
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except BrokenPipeError:
            pass

    def log_message(self, _format, *_args):
        pass


if __name__ == "__main__":
    Handler.audio = Path(sys.argv[2]).read_bytes()
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
