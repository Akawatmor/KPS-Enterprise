# PWA Icons

โปรดสร้างไอคอนสำหรับ PWA ตามขนาดต่อไปนี้:

- `icon-192.png` - 192x192 pixels
- `icon-512.png` - 512x512 pixels

ใช้สีธีมของแอป: #667eea (purple-blue gradient)

สามารถใช้เครื่องมือออนไลน์เช่น:
- https://www.pwabuilder.com/imageGenerator
- https://realfavicongenerator.net/
- Canva, Figma หรือเครื่องมือดีไซน์อื่นๆ

หรือใช้คำสั่ง ImageMagick เพื่อสร้างจาก logo หลัก:
```bash
convert logo.png -resize 192x192 icon-192.png
convert logo.png -resize 512x512 icon-512.png
```
