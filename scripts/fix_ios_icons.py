#!/usr/bin/env python3
"""
Remove alpha channels from iOS app icons and optimize file sizes.
Converts RGBA PNGs to RGB (no transparency), which resolves iOS build rejections.
"""

import os
from pathlib import Path
from PIL import Image

def fix_ios_icons():
    """Remove alpha channels from all app icons in AppIcon.appiconset."""
    icon_dir = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
    
    if not icon_dir.exists():
        print(f"❌ Icon directory not found: {icon_dir}")
        return False
    
    # Find all PNG icon files (exclude Contents.json)
    icon_files = sorted(icon_dir.glob("Icon-App-*.png"))
    
    if not icon_files:
        print(f"❌ No icon files found in {icon_dir}")
        return False
    
    fixed_count = 0
    for icon_path in icon_files:
        try:
            # Open image
            img = Image.open(icon_path)
            original_size = icon_path.stat().st_size
            
            # Convert RGBA to RGB with white background
            if img.mode in ("RGBA", "LA", "P"):
                # Create white background
                background = Image.new("RGB", img.size, (255, 255, 255))
                
                # Paste image with alpha channel
                if img.mode == "P":
                    img = img.convert("RGBA")
                
                background.paste(img, mask=img.split()[-1] if img.mode in ("RGBA", "LA") else None)
                img = background
            else:
                # Already RGB, ensure it's RGB mode
                img = img.convert("RGB")
            
            # Save with high quality and optimization
            img.save(icon_path, "PNG", quality=95, optimize=True)
            new_size = icon_path.stat().st_size
            size_reduction = original_size - new_size
            
            print(f"✅ {icon_path.name:30s} | was {original_size:6d}B → {new_size:6d}B ({size_reduction:+6d}B)")
            fixed_count += 1
        except Exception as e:
            print(f"❌ {icon_path.name}: {e}")
    
    print(f"\n✅ Fixed {fixed_count}/{len(icon_files)} icons successfully!")
    print(f"📁 All icons are now RGB (no alpha channels)")
    return True

if __name__ == "__main__":
    success = fix_ios_icons()
    exit(0 if success else 1)
