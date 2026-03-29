#!/usr/bin/env python3
"""Generate DMG background images for Clipper Zero.

Creates 1x (660x400) and 2x (1320x800) Retina backgrounds with a light
gradient and a subtle drag-arrow between the app icon and Applications.
"""

import sys
import math

import Quartz
from Quartz import (
    CGBitmapContextCreate,
    CGBitmapContextCreateImage,
    CGColorSpaceCreateDeviceRGB,
    CGContextAddLineToPoint,
    CGContextBeginPath,
    CGContextClosePath,
    CGContextDrawLinearGradient,
    CGContextFillPath,
    CGContextMoveToPoint,
    CGContextRestoreGState,
    CGContextSaveGState,
    CGContextSetLineCap,
    CGContextSetLineWidth,
    CGContextSetRGBFillColor,
    CGContextSetRGBStrokeColor,
    CGContextStrokePath,
    CGGradientCreateWithColorComponents,
    CGImageDestinationAddImage,
    CGImageDestinationCreateWithURL,
    CGImageDestinationFinalize,
    CGPointMake,
    CGRectMake,
    kCGImageAlphaPremultipliedLast,
    kCGLineCapRound,
)
from CoreFoundation import CFURLCreateWithFileSystemPath, kCFURLPOSIXPathStyle


def create_background(width, height, output_path):
    scale = width / 660.0
    color_space = CGColorSpaceCreateDeviceRGB()
    ctx = CGBitmapContextCreate(
        None, width, height, 8, width * 4, color_space, kCGImageAlphaPremultipliedLast
    )

    # ── Light gradient background ────────────────────────────────
    # Light theme ensures Finder's black icon labels are always readable
    colors = [
        0.95, 0.95, 0.96, 1.0,  # top: near white
        0.88, 0.88, 0.90, 1.0,  # bottom: light gray
    ]
    gradient = CGGradientCreateWithColorComponents(
        color_space, colors, [0.0, 1.0], 2
    )
    CGContextDrawLinearGradient(
        ctx, gradient,
        CGPointMake(0, height), CGPointMake(0, 0),
        0,
    )

    # ── Subtle arrow from app icon to Applications ───────────────
    # Icon centers at x=180 and x=480 (in 1x coordinates)
    # Icons are at y=170 from top in Finder coords = (400-170)/400 = 0.575 in CG
    icon_y = height * 0.58  # aligned with icon centers
    arrow_left = 260 * scale
    arrow_right = 400 * scale
    arrow_mid = (arrow_left + arrow_right) / 2

    CGContextSaveGState(ctx)

    # Dashed arrow line
    CGContextSetRGBStrokeColor(ctx, 0.55, 0.55, 0.58, 1.0)
    CGContextSetLineWidth(ctx, 2.5 * scale)
    CGContextSetLineCap(ctx, kCGLineCapRound)

    # Draw dotted shaft
    dash_len = 8.0 * scale
    gap_len = 6.0 * scale
    x = arrow_left
    while x < arrow_right - 15 * scale:
        CGContextMoveToPoint(ctx, x, icon_y)
        end_x = min(x + dash_len, arrow_right - 15 * scale)
        CGContextAddLineToPoint(ctx, end_x, icon_y)
        CGContextStrokePath(ctx)
        x += dash_len + gap_len

    # Arrowhead (filled triangle)
    head_size = 10.0 * scale
    CGContextSetRGBFillColor(ctx, 0.55, 0.55, 0.58, 1.0)
    CGContextBeginPath(ctx)
    CGContextMoveToPoint(ctx, arrow_right, icon_y)
    CGContextAddLineToPoint(ctx, arrow_right - head_size * 1.5, icon_y + head_size)
    CGContextAddLineToPoint(ctx, arrow_right - head_size * 1.5, icon_y - head_size)
    CGContextClosePath(ctx)
    CGContextFillPath(ctx)

    CGContextRestoreGState(ctx)

    # ── Save as PNG ──────────────────────────────────────────────
    image = CGBitmapContextCreateImage(ctx)
    url = CFURLCreateWithFileSystemPath(None, output_path, kCFURLPOSIXPathStyle, False)
    dest = CGImageDestinationCreateWithURL(url, "public.png", 1, None)
    CGImageDestinationAddImage(dest, image, None)
    CGImageDestinationFinalize(dest)


if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    bg_1x = f"{out_dir}/dmg-background.png"
    bg_2x = f"{out_dir}/dmg-background@2x.png"

    create_background(660, 400, bg_1x)
    create_background(1320, 800, bg_2x)
    print(f"Generated: {bg_1x}, {bg_2x}")
