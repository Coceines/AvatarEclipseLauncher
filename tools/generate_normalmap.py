#!/usr/bin/env python3
"""
Normal Map Generator for OTClient
Generates tangent-space normal maps from sprite PNG images.

Usage:
    python generate_normalmap.py <input.png> <output_n.png> [--strength 2.0]
    python generate_normalmap.py --batch <input_dir> <output_dir> [--strength 2.0]

The generated normal maps follow the tangent-space convention:
    R = X (left-right)
    G = Y (up-down)  
    B = Z (outward, always positive)
    
A neutral/flat surface maps to RGB(128, 128, 255) = normal (0, 0, 1).
"""

import sys
import os
import math

def generate_normal_map_from_heightmap(height_data, width, height, strength=2.0):
    """
    Generate a normal map from a heightmap using Sobel filter.
    
    height_data: flat array of height values (0.0 - 1.0)
    width, height: dimensions
    strength: normal map intensity (higher = more pronounced bumps)
    """
    normal_data = bytearray(width * height * 4)
    
    for y in range(height):
        for x in range(width):
            idx = (y * width + x) * 4
            
            # Sample surrounding heights (with wrapping)
            def get_height(px, py):
                px = max(0, min(width - 1, px))
                py = max(0, min(height - 1, py))
                return height_data[py * width + px]
            
            # Sobel filter for gradient
            tl = get_height(x - 1, y - 1)
            t  = get_height(x,     y - 1)
            tr = get_height(x + 1, y - 1)
            l  = get_height(x - 1, y)
            r  = get_height(x + 1, y)
            bl = get_height(x - 1, y + 1)
            b  = get_height(x,     y + 1)
            br = get_height(x + 1, y + 1)
            
            # Compute gradient
            dx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl)
            dy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr)
            
            # Normal vector
            nx = -dx * strength
            ny = -dy * strength
            nz = 1.0
            
            # Normalize
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            if length > 0:
                nx /= length
                ny /= length
                nz /= length
            
            # Convert from [-1, 1] to [0, 255]
            normal_data[idx]     = int((nx * 0.5 + 0.5) * 255)  # R = X
            normal_data[idx + 1] = int((ny * 0.5 + 0.5) * 255)  # G = Y
            normal_data[idx + 2] = int((nz * 0.5 + 0.5) * 255)  # B = Z
            normal_data[idx + 3] = 255                           # A = opaque
    
    return bytes(normal_data)


def read_png_simple(filepath):
    """
    Read a PNG file and return raw RGBA pixel data.
    Uses PIL/Pillow if available, otherwise tries png module.
    """
    try:
        from PIL import Image
        img = Image.open(filepath).convert('RGBA')
        return list(img.getdata()), img.width, img.height
    except ImportError:
        pass
    
    try:
        import png
        reader = png.Reader(filepath)
        w, h, pixels, metadata = reader.read()
        flat = []
        for row in pixels:
            flat.extend(row)
        # Convert from RGB/RGBA to flat list
        channels = 4 if metadata.get('alpha', True) else 3
        return flat, w, h
    except ImportError:
        pass
    
    raise RuntimeError("Need PIL/Pillow or pypng to read PNG files. Install with: pip install Pillow")


def write_png(filepath, pixel_data, width, height):
    """Write RGBA pixel data to a PNG file."""
    try:
        from PIL import Image
        img = Image.frombytes('RGBA', (width, height), bytes(pixel_data))
        img.save(filepath)
        return
    except ImportError:
        pass
    
    try:
        import png
        # Split into rows
        rows = []
        for y in range(height):
            row = pixel_data[y * width * 4 : (y + 1) * width * 4]
            rows.append(row)
        writer = png.Writer(width, height, alpha=True)
        with open(filepath, 'wb') as f:
            writer.write(f, rows)
        return
    except ImportError:
        pass
    
    raise RuntimeError("Need PIL/Pillow or pypng to write PNG files")


def process_image(input_path, output_path, strength=2.0):
    """Generate a normal map from a single image."""
    pixel_data, width, height = read_png_simple(input_path)
    
    # Extract alpha channel as height map
    # Use alpha where available, otherwise use luminance
    has_alpha = len(pixel_data) >= width * height * 4
    
    height_data = []
    for y in range(height):
        for x in range(width):
            idx = (y * width + x)
            if has_alpha:
                alpha = pixel_data[idx * 4 + 3] if len(pixel_data) > idx * 4 + 3 else 255
                r = pixel_data[idx * 4]
                g = pixel_data[idx * 4 + 1]
                b = pixel_data[idx * 4 + 2]
                # Use alpha as primary height, with luminance as detail
                luminance = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
                alpha_f = alpha / 255.0
                height_data.append(luminance * alpha_f)
            else:
                r = pixel_data[idx * 3]
                g = pixel_data[idx * 3 + 1]
                b = pixel_data[idx * 3 + 2]
                luminance = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
                height_data.append(luminance)
    
    normal_data = generate_normal_map_from_heightmap(height_data, width, height, strength)
    write_png(output_path, normal_data, width, height)
    print(f"  Generated: {output_path} ({width}x{height})")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    strength = 2.0
    
    # Parse --strength flag
    args = sys.argv[1:]
    if '--strength' in args:
        idx = args.index('--strength')
        if idx + 1 < len(args):
            strength = float(args[idx + 1])
            args = args[:idx] + args[idx + 2:]
    
    if args[0] == '--batch':
        # Batch mode: process all PNGs in a directory
        if len(args) < 3:
            print("Usage: generate_normalmap.py --batch <input_dir> <output_dir> [--strength 2.0]")
            sys.exit(1)
        
        input_dir = args[1]
        output_dir = args[2]
        os.makedirs(output_dir, exist_ok=True)
        
        count = 0
        for filename in sorted(os.listdir(input_dir)):
            if filename.lower().endswith('.png'):
                input_path = os.path.join(input_dir, filename)
                output_name = os.path.splitext(filename)[0] + '_n.png'
                output_path = os.path.join(output_dir, output_name)
                try:
                    process_image(input_path, output_path, strength)
                    count += 1
                except Exception as e:
                    print(f"  Error processing {filename}: {e}")
        
        print(f"\nProcessed {count} images")
    else:
        # Single file mode
        input_path = args[0]
        if len(args) > 1:
            output_path = args[1]
        else:
            base, ext = os.path.splitext(input_path)
            output_path = base + '_n' + ext
        
        process_image(input_path, output_path, strength)
        print("Done!")


if __name__ == '__main__':
    main()
