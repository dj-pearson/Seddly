import struct, zlib

def create_png(width, height):
    """Create a PNG with Seddly brand colors: blue rounded rect with white checkmark."""
    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xffffffff)
        return struct.pack('>I', len(data)) + c + crc

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))

    raw = b''
    sw = max(1, width // 10)
    cr = width * 0.19

    for y in range(height):
        raw += b'\x00'
        for x in range(width):
            x1, y1 = 0.25 * width, 0.5 * height
            x2, y2 = 0.4 * width, 0.7 * height
            x3, y3 = 0.75 * width, 0.3 * height

            def dist_to_seg(px, py, ax, ay, bx, by):
                dx, dy = bx - ax, by - ay
                if dx == 0 and dy == 0:
                    return ((px-ax)**2 + (py-ay)**2)**0.5
                t = max(0, min(1, ((px-ax)*dx + (py-ay)*dy) / (dx*dx + dy*dy)))
                proj_x, proj_y = ax + t*dx, ay + t*dy
                return ((px-proj_x)**2 + (py-proj_y)**2)**0.5

            d1 = dist_to_seg(x, y, x1, y1, x2, y2)
            d2 = dist_to_seg(x, y, x2, y2, x3, y3)
            d = min(d1, d2)

            in_rect = True
            for (cx_, cy_) in [(cr, cr), (width-cr, cr), (cr, height-cr), (width-cr, height-cr)]:
                if (x < cr or x > width-cr) and (y < cr or y > height-cr):
                    if ((x-cx_)**2 + (y-cy_)**2) > cr*cr:
                        in_rect = False

            if not in_rect:
                raw += bytes([10, 10, 11])
            elif d < sw:
                raw += bytes([255, 255, 255])
            else:
                raw += bytes([91, 127, 245])

    compressed = zlib.compress(raw)
    idat = chunk(b'IDAT', compressed)
    iend = chunk(b'IEND', b'')
    return sig + ihdr + idat + iend

base = 'C:/Users/pears/Documents/Seddly/Seddly/website/public'
for name, w, h in [
    ('favicon-16x16.png', 16, 16),
    ('favicon-32x32.png', 32, 32),
    ('apple-touch-icon.png', 180, 180),
    ('og-image.png', 1200, 630),
]:
    data = create_png(w, h)
    with open(f'{base}/{name}', 'wb') as f:
        f.write(data)
    print(f'Created {name} ({w}x{h}, {len(data)} bytes)')
