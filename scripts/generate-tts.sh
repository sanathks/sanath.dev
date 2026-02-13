#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BLOG_DIR="$SCRIPT_DIR/../src/data/blog"
AUDIO_DIR="$SCRIPT_DIR/../public/audio"
VOICE="en-US-AndrewNeural"

mkdir -p "$AUDIO_DIR"

strip_markdown() {
  python3 -c "
import re, sys
text = sys.stdin.read()
text = re.sub(r'^---\n.*?\n---\n', '', text, flags=re.DOTALL)
text = re.sub(r'\`\`\`[\s\S]*?\`\`\`', '', text)
text = re.sub(r'\`[^\`]+\`', '', text)
text = re.sub(r'^\|.*\|$', '', text, flags=re.MULTILINE)
text = re.sub(r'^[\s]*[-|:]+[-|:\s]+$', '', text, flags=re.MULTILINE)
text = re.sub(r'!\[([^\]]*)\]\([^)]+\)', r'\1', text)
text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
text = re.sub(r'<[^>]+>', '', text)
text = re.sub(r'^#{1,6}\s+', '', text, flags=re.MULTILINE)
text = re.sub(r'\*{1,3}([^*]+)\*{1,3}', r'\1', text)
text = re.sub(r'_{1,3}([^_]+)_{1,3}', r'\1', text)
text = re.sub(r'^>\s*', '', text, flags=re.MULTILINE)
text = re.sub(r'^[-*_]{3,}\s*$', '', text, flags=re.MULTILINE)
text = re.sub(r'^\s*[-*+]\s+', '', text, flags=re.MULTILINE)
text = re.sub(r'^\s*\d+\.\s+', '', text, flags=re.MULTILINE)
text = text.replace('\u2014', '-').replace('\u2013', '-')
# Fix acronym pronunciation - TTS spells these out otherwise
text = text.replace('RAG', 'rag')
text = text.replace('LLM', 'L L M')
text = re.sub(r'\n{3,}', '\n\n', text)
print(text.strip())
"
}

vtt_to_json() {
  python3 -c "
import re, json, sys
with open('$1') as f:
    content = f.read()
sentences = []
for match in re.finditer(r'(\d+)\n(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*\n(.+?)(?:\n\n|\n*$)', content, re.DOTALL):
    idx = int(match.group(1))
    h1,m1,s1,ms1 = int(match.group(2)),int(match.group(3)),int(match.group(4)),int(match.group(5))
    h2,m2,s2,ms2 = int(match.group(6)),int(match.group(7)),int(match.group(8)),int(match.group(9))
    text = match.group(10).strip().replace('\n', ' ')
    start = h1*3600 + m1*60 + s1 + ms1/1000
    end = h2*3600 + m2*60 + s2 + ms2/1000
    sentences.append({'text': text, 'start': round(start,3), 'end': round(end,3)})
json.dump(sentences, sys.stdout)
"
}

echo "Generating TTS for blog posts..."

for md_file in "$BLOG_DIR"/*.md; do
  slug="$(basename "$md_file" .md)"
  mp3_path="$AUDIO_DIR/$slug.mp3"
  json_path="$AUDIO_DIR/$slug.json"
  checksum_file="$AUDIO_DIR/.cksum-$slug"

  current_hash="$(md5sum "$md_file" | cut -d' ' -f1)"
  if [ -f "$mp3_path" ] && [ -f "$json_path" ] && [ -f "$checksum_file" ]; then
    saved_hash="$(cat "$checksum_file")"
    if [ "$current_hash" = "$saved_hash" ]; then
      echo "  skip: $slug"
      continue
    fi
  fi

  echo "  generating: $slug"
  prose="$(cat "$md_file" | strip_markdown)"
  echo "$prose" > /tmp/tts-input.txt
  echo "    ${#prose} chars"

  edge-tts --voice "$VOICE" --file /tmp/tts-input.txt \
    --write-media "$mp3_path" --write-subtitles /tmp/tts-output.vtt 2>/dev/null

  vtt_to_json /tmp/tts-output.vtt > "$json_path"
  echo "$current_hash" > "$checksum_file"

  size="$(du -h "$mp3_path" | cut -f1)"
  count="$(python3 -c "import json; print(len(json.load(open('$json_path'))))")"
  echo "    done: $count sentences, $size"
done

rm -f /tmp/tts-input.txt /tmp/tts-output.vtt
echo "All done!"
