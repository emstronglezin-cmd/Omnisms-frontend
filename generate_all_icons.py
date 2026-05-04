#!/usr/bin/env python3
"""
Generate OmniSMS branded icons for all platforms (Web, Android, iOS)
"""
from PIL import Image, ImageDraw
import os

# OmniSMS brand colors
BACKGROUND_COLOR = "#080c14"
ACCENT_COLOR = "#00d4ff"

def create_icon(size, output_path):
    """Create an OmniSMS branded icon with message bubble design"""
    # Create image with dark background
    img = Image.new('RGB', (size, size), BACKGROUND_COLOR)
    draw = ImageDraw.Draw(img)
    
    # Calculate dimensions for the message bubble
    padding = size * 0.15
    bubble_width = size - (2 * padding)
    bubble_height = bubble_width * 0.7
    
    # Position the bubble
    x1 = padding
    y1 = (size - bubble_height) / 2
    x2 = x1 + bubble_width
    y2 = y1 + bubble_height
    
    # Draw rounded rectangle for message bubble
    corner_radius = size * 0.15
    draw.rounded_rectangle(
        [(x1, y1), (x2, y2)],
        radius=corner_radius,
        fill=ACCENT_COLOR
    )
    
    # Draw small tail for the message bubble (triangle)
    tail_size = size * 0.08
    tail_x = x1 + (bubble_width * 0.2)
    tail_y = y2
    draw.polygon(
        [
            (tail_x, tail_y),
            (tail_x + tail_size, tail_y),
            (tail_x + (tail_size / 2), tail_y + tail_size)
        ],
        fill=ACCENT_COLOR
    )
    
    # Draw horizontal lines inside bubble to represent text
    line_padding = size * 0.08
    line_y_start = y1 + line_padding
    line_spacing = bubble_height * 0.25
    line_thickness = max(2, int(size * 0.015))
    
    for i in range(3):
        line_y = line_y_start + (i * line_spacing)
        line_width = bubble_width - (2 * line_padding)
        if i == 2:  # Last line shorter
            line_width *= 0.6
        
        draw.rounded_rectangle(
            [
                (x1 + line_padding, line_y),
                (x1 + line_padding + line_width, line_y + line_thickness)
            ],
            radius=line_thickness // 2,
            fill=BACKGROUND_COLOR
        )
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # Save the icon
    img.save(output_path, 'PNG', optimize=True)
    return output_path

def main():
    """Generate all required icon sizes for OmniSMS"""
    print("🎨 Generating OmniSMS branded icons...")
    print(f"   Background: {BACKGROUND_COLOR}")
    print(f"   Accent: {ACCENT_COLOR}\n")
    
    icons_generated = []
    
    # Web PWA icons
    web_icons = {
        'web/favicon.png': 32,
        'web/icons/Icon-192.png': 192,
        'web/icons/Icon-512.png': 512,
        'web/icons/Icon-maskable-192.png': 192,
        'web/icons/Icon-maskable-512.png': 512,
    }
    
    print("📱 Web PWA Icons:")
    for path, size in web_icons.items():
        output = create_icon(size, path)
        icons_generated.append(output)
        print(f"   ✓ {path} ({size}x{size})")
    
    # Android launcher icons
    android_icons = {
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    }
    
    print("\n🤖 Android Launcher Icons:")
    for path, size in android_icons.items():
        if os.path.exists(os.path.dirname(path)):
            output = create_icon(size, path)
            icons_generated.append(output)
            print(f"   ✓ {path} ({size}x{size})")
    
    # iOS icons (if directory exists)
    ios_icons = {
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png': 167,
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png': 1024,
    }
    
    ios_base = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    if os.path.exists(ios_base):
        print("\n🍎 iOS App Icons:")
        for path, size in ios_icons.items():
            output = create_icon(size, path)
            icons_generated.append(output)
            print(f"   ✓ {os.path.basename(path)} ({size}x{size})")
    
    print(f"\n✅ Successfully generated {len(icons_generated)} OmniSMS branded icons!")
    print("🚀 Flutter branding has been replaced with OmniSMS branding")

if __name__ == "__main__":
    main()
