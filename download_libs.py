import os
import urllib.request

# Base URLs
LIBS = {
    'js/marked.min.js': 'https://cdn.jsdelivr.net/npm/marked/marked.min.js',
    'js/flatpickr.js': 'https://cdn.jsdelivr.net/npm/flatpickr',
    'js/zh.js': 'https://npmcdn.com/flatpickr/dist/l10n/zh.js',
    'js/html2canvas.min.js': 'https://html2canvas.hertzen.com/dist/html2canvas.min.js',
    'css/flatpickr.min.css': 'https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css'
}

STATIC_DIR = os.path.join(os.path.dirname(__file__), 'static')

def download_file(url, path):
    print(f"Downloading {url} to {path}...")
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        # Add headers to avoid 403 Forbidden on some CDNs
        headers = {'User-Agent': 'Mozilla/5.0'}
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as response, open(path, 'wb') as out_file:
            data = response.read()
            out_file.write(data)
        print("Success.")
    except Exception as e:
        print(f"Error downloading {url}: {e}")

if __name__ == '__main__':
    for rel_path, url in LIBS.items():
        download_file(url, os.path.join(STATIC_DIR, rel_path))
