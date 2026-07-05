#!/usr/bin/env python3
"""
Single Gemini/Gemma hint call. Reads {api_key, model, system, prompt} as JSON on
stdin, prints {ok, hint} or {ok:false, quota, error}. Node handles key rotation
and per-user rate limiting; this just makes one call with the given key.

Uses the reliable config for gemma-4-31b-it: JSON response schema + system
instruction. (thinking_config 500s on Gemma; tools break the structured output,
so they are omitted - they add nothing to hint generation.)
"""
import json
import sys

from google import genai
from google.genai import types


def main() -> None:
    inp = json.load(sys.stdin)
    try:
        client = genai.Client(api_key=inp["api_key"])
        config = types.GenerateContentConfig(
            system_instruction=[types.Part.from_text(text=inp["system"])],
            response_mime_type="application/json",
            response_schema=genai.types.Schema(
                type=genai.types.Type.OBJECT,
                properties={"response": genai.types.Schema(type=genai.types.Type.STRING)},
            ),
            temperature=0.6,
        )
        contents = [types.Content(role="user", parts=[types.Part.from_text(text=inp["prompt"])])]
        resp = client.models.generate_content(model=inp.get("model", "gemma-4-31b-it"),
                                               contents=contents, config=config)
        text = (resp.text or "").strip()
        hint = ""
        try:
            hint = json.loads(text).get("response", "")
        except Exception:
            # strip markdown fences if the model wrapped it, else use raw text
            t = text.strip("`").replace("json\n", "", 1)
            try:
                hint = json.loads(t).get("response", "")
            except Exception:
                hint = text
        print(json.dumps({"ok": bool(hint.strip()), "hint": hint.strip()}))
    except Exception as e:  # noqa: BLE001
        msg = str(e)
        quota = any(s in msg for s in ("429", "RESOURCE_EXHAUSTED", "quota", "exhausted"))
        print(json.dumps({"ok": False, "quota": quota, "error": msg[:300]}))


if __name__ == "__main__":
    main()
