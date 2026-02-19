#!/usr/bin/env python3
"""
Generate iOS app icons from a source image.
Resizes real_logo.png to all required iOS icon dimensions and saves to ios/Runner/Assets.xcassets/AppIcon.appiconset/
"""

import os
from pathlib import Path
from PIL import Image

# Define all required iOS icon sizes
# Format: (base_size, scale) -> output filename
ICON_SIZES = [
    # iPhone icons
    ("20x20", "2x", "Icon-App-20x20@2x.png"),
    ("20x20", "3x", "Icon-App-20x20@3x.png"),
    ("29x29", "1x", "Icon-App-29x29@1x.png"),
    ("29x29", "2x", "Icon-App-29x29@2x.png"),
    ("29x29", "3x", "Icon-App-29x29@3x.png"),
    ("40x40", "2x", "Icon-App-40x40@2x.png"),
    ("40x40", "3x", "Icon-App-40x40@3x.png"),
    ("60x60", "2x", "Icon-App-60x60@2x.png"),
    ("60x60", "3x", "Icon-App-60x60@3x.png"),
    # iPad icons
    ("20x20", "1x", "Icon-App-20x20@1x.png"),
    ("40x40", "1x", "Icon-App-40x40@1x.png"),
    ("29x29", "1x", "Icon-App-29x29@1x.png"),
    ("76x76", "1x", "Icon-App-76x76@1x.png"),
    ("76x76", "2x", "Icon-App-76x76@2x.png"),
    ("50x50", "1x", "Icon-App-50x50@1x.png"),
    ("50x50", "2x", "Icon-App-50x50@2x.png"),
    ("57x57", "1x", "Icon-App-57x57@1x.png"),
    ("57x57", "2x", "Icon-App-57x57@2x.png"),
    ("72x72", "1x", "Icon-App-72x72@1x.png"),
    ("72x72", "2x", "Icon-App-72x72@2x.png"),
    ("83.5x83.5", "2x", "Icon-App-83.5x83.5@2x.png"),
    # App Store icon
    ("1024x1024", "1x", "Icon-App-1024x1024@1x.png"),
]

def size_to_pixels(size_str, scale_str):
    """Convert size string like '20x20' and scale like '2x' to actual pixel dimension."""
    base = float(size_str.split('x')[0])
    scale = float(scale_str.replace('x', ''))
    return int(base * scale)

def main():
    # Paths
    source_image = Path("assets/images/real_logo.png")
    output_dir = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
    
    # Validate source
    if not source_image.exists():
        print(f"❌ Error: {source_image} not found!")
        return False
    
    # Ensure output dir exists
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Open source image
    try:
        img = Image.open(source_image)
        print(f"✅ Opened source image: {source_image} ({img.size})")
    except Exception as e:
        print(f"❌ Error opening image: {e}")
        return False
    
    # Generate each icon size
    generated = 0
    for base_size, scale, filename in ICON_SIZES:
        try:
            pixel_size = size_to_pixels(base_size, scale)
            output_path = output_dir / filename
            
            # Resize using high-quality resampling
            resized = img.resize((pixel_size, pixel_size), Image.LANCZOS)
            resized.save(output_path, "PNG", quality=95)
            
            print(f"✅ {filename:30s} ({pixel_size}x{pixel_size})")
            generated += 1
        except Exception as e:
            print(f"❌ {filename}: {e}")
    
    print(f"\n✅ Generated {generated}/{len(ICON_SIZES)} icons successfully!")
    print(f"📁 Icons saved to: {output_dir}")
    return True

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
