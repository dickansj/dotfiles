#!/usr/bin/env python3
import argparse
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from PyPDF2 import PdfReader
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
import requests

# ----- CONFIG -----
DEEPL_API_KEY = os.environ.get("DEEPL_API_KEY")
if not DEEPL_API_KEY:
    raise ValueError("DEEPL_API_KEY environment variable not set.")

# Detect Free vs Pro automatically
def detect_plan():
    try:
        test_url = "https://api.deepl.com/v2/usage"  # Only Pro accounts can access /v2/usage
        response = requests.get(test_url, headers={"Authorization": f"DeepL-Auth-Key {DEEPL_API_KEY}"})
        if response.status_code == 200:
            return "PRO", "https://api.deepl.com/v2/translate"
        else:
            return "FREE", "https://api-free.deepl.com/v2/translate"
    except requests.RequestException:
        return "FREE", "https://api-free.deepl.com/v2/translate"

PLAN_TYPE, DEEPL_URL = detect_plan()
print(f"🌐 Detected DeepL plan: {PLAN_TYPE}, using endpoint {DEEPL_URL}")

MAX_WORKERS = 8  # initial safe number of concurrent translations
MAX_RETRIES = 5
INITIAL_BACKOFF = 2  # seconds
CHUNK_SIZE = 5000  # approx chars per chunk

# ----- FUNCTIONS -----
def extract_text(pdf_path):
    reader = PdfReader(pdf_path)
    text = ""
    for page in reader.pages:
        txt = page.extract_text()
        if txt:
            text += txt + "\n\n"
    return text

def split_into_chunks(text, chunk_size=CHUNK_SIZE):
    paragraphs = text.split("\n\n")
    chunks = []
    current_chunk = ""
    for para in paragraphs:
        if len(current_chunk) + len(para) < chunk_size:
            current_chunk += para + "\n\n"
        else:
            if current_chunk.strip():
                chunks.append(current_chunk.strip())
            current_chunk = para + "\n\n"
    if current_chunk.strip():
        chunks.append(current_chunk.strip())
    return chunks

def translate_chunk(chunk, target_lang="EN"):
    backoff = INITIAL_BACKOFF
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = requests.post(
                DEEPL_URL,
                data={"text": chunk, "target_lang": target_lang},
                headers={"Authorization": f"DeepL-Auth-Key {DEEPL_API_KEY}"},
                timeout=60
            )
            if response.status_code == 200:
                return response.json()["translations"][0]["text"]
            elif response.status_code == 456:
                print(f"⚠️  456 rate limit, retrying in {backoff}s...")
                time.sleep(backoff)
                backoff *= 2
            else:
                response.raise_for_status()
        except requests.RequestException as e:
            print(f"❌ Attempt {attempt} failed: {e}")
            time.sleep(backoff)
            backoff *= 2
    raise Exception("❌ Translation failed after multiple retries.")

def translate_chunks_adaptive(chunks, target_lang="EN"):
    global MAX_WORKERS
    translated_chunks = [None] * len(chunks)
    idx_list = list(range(len(chunks)))

    while idx_list:
        # Submit up to MAX_WORKERS chunks
        batch = idx_list[:MAX_WORKERS]
        idx_list = idx_list[MAX_WORKERS:]

        with ThreadPoolExecutor(max_workers=len(batch)) as executor:
            future_to_idx = {executor.submit(translate_chunk, chunks[i], target_lang): i for i in batch}
            for future in as_completed(future_to_idx):
                i = future_to_idx[future]
                try:
                    translated_chunks[i] = future.result()
                except Exception as e:
                    print(f"⚠️ Chunk {i} failed with error: {e}")
                    # reduce concurrency if repeated 456s occur
                    if MAX_WORKERS > 1:
                        MAX_WORKERS -= 1
                        print(f"⚠️ Reducing concurrency to {MAX_WORKERS}")
                    # retry sequentially, but don't let one bad chunk take
                    #   down every already-translated chunk in this run
                    try:
                        translated_chunks[i] = translate_chunk(chunks[i], target_lang)
                    except Exception as e2:
                        print(f"❌ Chunk {i} failed permanently: {e2}")
                        translated_chunks[i] = f"[TRANSLATION FAILED FOR THIS SECTION: {e2}]"
    return translated_chunks

def save_txt(text, output_path):
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(text)

def save_pdf(text, output_path):
    c = canvas.Canvas(output_path, pagesize=letter)
    width, height = letter
    font_name, font_size = "Helvetica", 10
    margin = 50
    max_width = width - 2 * margin
    c.setFont(font_name, font_size)

    def wrap_line(line):
        if not line:
            return [""]
        words = line.split(" ")
        wrapped = []
        current = ""
        for word in words:
            candidate = word if not current else f"{current} {word}"
            if c.stringWidth(candidate, font_name, font_size) <= max_width:
                current = candidate
            else:
                if current:
                    wrapped.append(current)
                current = word
        if current:
            wrapped.append(current)
        return wrapped or [""]

    lines = text.split("\n")
    y = height - margin
    for line in lines:
        for sub_line in wrap_line(line):
            c.drawString(margin, y, sub_line)
            y -= 14
            if y < margin:
                c.showPage()
                c.setFont(font_name, font_size)
                y = height - margin
    c.save()

# ----- MAIN -----
def main():
    parser = argparse.ArgumentParser(description="Translate PDF via DeepL")
    parser.add_argument("input_pdf", help="Input PDF path")
    parser.add_argument("output_pdf", help="Output PDF path")
    parser.add_argument("--lang", default="EN", help="Target language (default EN)")
    parser.add_argument("--txt", action="store_true", help="Also export .txt file")
    args = parser.parse_args()

    print("📄 Extracting text...")
    text = extract_text(args.input_pdf)
    print("✂️  Splitting into chunks...")
    chunks = split_into_chunks(text)
    print(f"🔢 {len(chunks)} chunks detected. Translating adaptively...")

    translated_chunks = translate_chunks_adaptive(chunks, target_lang=args.lang)
    translated_text = "\n\n".join(translated_chunks)

    print("💾 Saving PDF...")
    save_pdf(translated_text, args.output_pdf)

    if args.txt:
        txt_path = os.path.splitext(args.output_pdf)[0] + ".txt"
        print(f"💾 Saving TXT: {txt_path}")
        save_txt(translated_text, txt_path)

    print("✅ Translation complete.")

if __name__ == "__main__":
    main()
