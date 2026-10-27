"""Loopback DeepSeek response fixture; it never contacts DeepSeek or reads .env."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import sys
import time


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        try:
            request = json.loads(raw)
            messages = request["messages"]
            learner = json.loads(messages[1]["content"])
            valid = (
                self.headers.get("Authorization") == "Bearer fixture-deepseek-key"
                and self.headers.get("X-goog-api-key") is None
                and request["model"] == "deepseek-flash"
                and request["response_format"] == {"type": "json_object"}
                and request["thinking"] == {"type": "disabled"}
                and request["stream"] is False
                and messages[0]["role"] == "system"
                and "Reward clear polite requests." in messages[0]["content"]
                and "JSON" in messages[0]["content"]
                and "off-target" in messages[0]["content"]
                and messages[1]["role"] == "user"
                and learner["transcript"] == "Where are the bananas?"
                and learner["target_vocabulary"] == ["bananas", "please", "where"]
                and learner["examples"][0]["quality"] == 1
            )
        except (KeyError, IndexError, TypeError, ValueError):
            valid = False
        if not valid:
            self.respond(400, {"error": "Bad DeepSeek request"})
            return

        if self.path == "/blocked":
            self.respond(200, {"choices": [{"finish_reason": "content_filter", "message": {"content": ""}}]})
        elif self.path == "/malformed":
            self.respond(200, {"choices": [{"finish_reason": "stop", "message": {"content": "not JSON"}}]})
        elif self.path == "/truncated":
            self.respond(200, {"choices": [{"finish_reason": "length", "message": {"content": "{"}}]})
        elif self.path == "/slow":
            time.sleep(0.6)
            self.respond(200, self.assessment())
        elif self.path == "/evaluate":
            self.respond(200, self.assessment())
        else:
            self.respond(404, {"error": "Not found"})

    @staticmethod
    def assessment():
        value = {
            "quality": 1,
            "feedback": "That is correct English!",
            "pip_response": "Great job! You asked clearly about the bananas. Adding please would make it even friendlier!",
            "suggested_wording": "Excuse me, where are the bananas?",
            "vocabulary_used": [{"word": "bananas", "evidence": "bananas"}],
        }
        return {"choices": [{"finish_reason": "stop", "message": {"content": json.dumps(value)}}]}

    def respond(self, status, value):
        body = json.dumps(value).encode()
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except BrokenPipeError:
            pass

    def log_message(self, _format, *_args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
