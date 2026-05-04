#!/usr/bin/env python3
"""
Generate OmniSMS branded icons for Flutter web PWA
"""
from PIL import Image, ImageDraw, ImageFont
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
    
    # Save the icon
    img.save(output_path, 'PNG', optimize=True)
    print(f"Created: {output_path} ({size}x{size})")

def main():
    """Generate all required icon sizes for OmniSMS"""
    # Create web icons directory if it doesn't exist
    icons_dir = "web/icons"
    os.makedirs(icons_dir, exist_ok=True)
    
    # Generate icons in required sizes
    icon_sizes = {
        'web/favicon.png': 32,
        'web/icons/Icon-192.png': 192,
        'web/icons/Icon-512.png': 512,
        'web/icons/Icon-maskable-192.png': 192,
        'web/icons/Icon-maskable-512.png': 512,
    }
    
    for path, size in icon_sizes.items():
        create_icon(size, path)
    
    print("\n✅ All OmniSMS icons generated successfully!")
    print("🎨 Brand colors used: Background #080c14, Accent #00d4ff")

if __name__ == "__main__":
    main()
