import re
import requests
from urllib.parse import unquote

url = input("Enter URL:")

headers = {
    "User-Agent": "Mozilla/5.0"
}

response = requests.get(url, headers=headers, timeout=30)
response.raise_for_status()

html = response.text

matches = re.findall(r'https?://[^"\']+\.(?:jpg|jpeg|png|webp)', html, re.IGNORECASE)

image_links = set()

for link in matches:
    link = unquote(link)

    if "/photos/uploadsExt/uploads/" not in link:
        continue

    if "/photos/assets/images/" in link:
        continue

    if "/home_images/" in link:
        continue

    image_links.add(link)

for img_url in sorted(image_links):
    print(img_url)