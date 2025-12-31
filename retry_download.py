import os
import urllib.request
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

urls = [
    'https://cdn.bootcdn.net/ajax/libs/html2canvas/1.4.1/html2canvas.min.js',
    'https://unpkg.com/html2canvas@1.4.1/dist/html2canvas.min.js',
    'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js'
]
path = os.path.join(os.path.dirname(__file__), 'static', 'js', 'html2canvas.min.js')

print(f"Target: {path}")

for url in urls:
    print(f"Trying {url}...")
    try:
        headers = {'User-Agent': 'Mozilla/5.0'}
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, context=ctx, timeout=10) as response, open(path, 'wb') as out_file:
            data = response.read()
            out_file.write(data)
        print("Success.")
        break
    except Exception as e:
        print(f"Failed: {e}")
