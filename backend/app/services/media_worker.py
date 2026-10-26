"""Isolated local file extraction; invoked by asset_service, never a public endpoint."""
import json
import sys
from pathlib import Path


def extract(path, mime, source, audio_model, ocr):
    if mime == "application/pdf":
        from pypdf import PdfReader
        reader = PdfReader(path)
        if reader.is_encrypted or len(reader.pages) > 30:
            raise ValueError("pdf_encrypted_or_page_limit")
        pages = [{"source_id": f"{source}:page:{i+1}", "content": (page.extract_text() or "")[:12000]}
                 for i, page in enumerate(reader.pages)]
        if any(page["content"].strip() for page in pages):
            return pages
        if not ocr:
            raise ValueError("scanned_pdf_requires_ocr")
        from docling.document_converter import DocumentConverter
        result = DocumentConverter().convert(path, max_num_pages=30, max_file_size=10485760)
        return [{"source_id": f"{source}:ocr", "content": result.document.export_to_markdown()[:30000]}]
    if mime.startswith("audio/"):
        from faster_whisper import WhisperModel
        segments, info = WhisperModel(audio_model, device="cpu", compute_type="int8").transcribe(str(path), vad_filter=True)
        if info.duration > 300:
            raise ValueError("audio_duration_limit")
        result = []
        for segment in segments:
            result.append({"source_id": f"{source}:seconds:{segment.start:.1f}-{segment.end:.1f}", "content": segment.text[:3000]})
            if len(result) >= 100:
                break
        return result
    raise ValueError("unsupported_file_format")


def main():
    input_path, output_path = map(Path, sys.argv[1:3])
    job = json.loads(input_path.read_text(encoding="utf-8"))
    try:
        # Linux worker defense-in-depth. Containers should also set memory/CPU limits.
        try:
            import resource
            resource.setrlimit(resource.RLIMIT_CPU, (120, 120))
        except ImportError:
            pass
        sources = extract(Path(job["path"]), job["mime"], job["source"], job["audio_model"], job["ocr"])
        result = {"sources": sources}
    except ModuleNotFoundError:
        result={"error":"media_engine_unavailable"}
    except Exception as exc:
        # Only known safe error codes leave the parser process.
        allowed = {"pdf_encrypted_or_page_limit", "scanned_pdf_requires_ocr", "audio_duration_limit"}
        result = {"error": str(exc) if str(exc) in allowed else "media_extraction_failed"}
    output_path.write_text(json.dumps(result), encoding="utf-8")


if __name__ == "__main__":
    main()
