import io
import pytest
from PIL import Image
from app.services.asset_service import validate_asset, extract_asset
from app.schemas.workflow import Plan


def test_image_signature_and_decode():
    buffer = io.BytesIO()
    Image.new("RGB", (8, 8)).save(buffer, format="PNG")
    assert validate_asset(buffer.getvalue()) == "image/png"
    with pytest.raises((ValueError, OSError)):
        validate_asset(b"\x89PNG\r\n\x1a\ninvalid")


def test_invalid_file_and_scanned_pdf_fail_explicitly():
    with pytest.raises(ValueError): validate_asset(b"<script>bad</script>")
    from pypdf import PdfWriter
    buffer = io.BytesIO(); writer = PdfWriter(); writer.add_blank_page(100,100); writer.write(buffer)
    with pytest.raises(ValueError, match="scanned_pdf_requires_ocr"):
        extract_asset(buffer.getvalue(), "application/pdf", "asset", None)


def test_schema_bounds():
    with pytest.raises(ValueError):
        Plan(tasks=[{"title":"Study","source_id":"entry","evidence":"Study","xp_value":100}],coaching_insight="Start")
