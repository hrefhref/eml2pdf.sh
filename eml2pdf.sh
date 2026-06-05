#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 path/to/file.eml"
  exit 1
fi

EML="$1"
HTML="${EML}.html"
PDF="${EML}.pdf"

python3 - "$EML" "$HTML" <<'EOF'
import email, email.header, email.utils, sys, re

eml_path = sys.argv[1]
html_path = sys.argv[2]

with open(eml_path) as f:
    msg = email.message_from_file(f)

def decode_header(value):
    """Decode RFC 2047 encoded header into a plain string."""
    if not value:
        return ''
    parts = email.header.decode_header(value)
    return ''.join(
        part.decode(enc or 'utf-8') if isinstance(part, bytes) else part
        for part, enc in parts
    )

def format_address(value):
    """Return 'Name <address>' or just 'address' if no name."""
    decoded = decode_header(value)
    name, addr = email.utils.parseaddr(decoded)
    if name and addr:
        return f"{name} &lt;{addr}&gt;"
    return addr or decoded

from_h    = format_address(msg.get('From', ''))
to_h      = format_address(msg.get('To', ''))
subject_h = decode_header(msg.get('Subject', ''))
date_h    = msg.get('Date', '')

header_html = f"""
<div style="background-color: white; font-family: monospace; font-size: 13px; border-bottom: 1px solid #ccc; padding: 10px 16px; margin-bottom: 16px; color: #333;">
  <div><strong>From:</strong> {from_h}</div>
  <div><strong>To:</strong> {to_h}</div>
  <div><strong>Subject:</strong> {subject_h}</div>
  <div><strong>Date:</strong> {date_h}</div>
</div>
"""

for part in msg.walk():
    if part.get_content_type() == 'text/html':
        html = part.get_payload(decode=True).decode('utf-8', errors='replace')
        if '<body' in html.lower():
            html = re.sub(r'(<body[^>]*>)', r'\1' + header_html, html, count=1, flags=re.IGNORECASE)
        else:
            html = header_html + html
        with open(html_path, 'w') as out:
            out.write(html)
        break

EOF

echo "Created $HTML"

/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --headless \
  --print-to-pdf="$PDF" \
  --no-pdf-header-footer \
  --no-margins \
  "file://$(realpath "$HTML")"

echo "Created $PDF"
