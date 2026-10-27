"""Local HTTP fixture for the GDScript speech adapter check."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import sys
import time


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if self.path == "/transcribe":
            valid = self.headers.get("Content-Type") == "audio/wav" and body[:4] == b"RIFF"
            response = {"transcript": "Where are the bananas?"} if valid else {"error": "bad wave"}
            status = 200 if valid else 400
        elif self.path == "/evaluate":
            request = json.loads(body)
            valid = request.get("transcript") == "Where are the bananas?" and request.get("target_vocabulary") == ["bananas"]
            response = {
                "quality": 1,
                "feedback": "Correct English.",
                "suggested_wording": "Could you show me the bananas?",
                "pip_response": "Great! You asked for bananas clearly.",
                "vocabulary_used": [{"word": "bananas", "evidence": "bananas"}],
            } if valid else {"error": "bad lesson"}
            status = 200 if valid else 400
        elif self.path == "/slow":
            time.sleep(0.5)
            response, status = {"transcript": "Late answer"}, 200
        else:
            response, status = {"error": "unknown path"}, 404
        data = json.dumps(response).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except BrokenPipeError:
            pass

    def log_message(self, _format, *_args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
