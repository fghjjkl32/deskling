#!/usr/bin/env swift
// Draws frames bottom-centered on one shared canvas, scales them, and writes a (possibly animated) PNG.
// Usage: make-apng.swift <out.png> <delay-seconds> <canvas-width> <canvas-height> <output-height> <frame.png>...
import CoreGraphics
import Foundation
import ImageIO

let arguments = CommandLine.arguments
guard arguments.count >= 7,
      let delay = Double(arguments[2]),
      let canvasWidth = Double(arguments[3]), let canvasHeight = Double(arguments[4]),
      let outputHeight = Int(arguments[5]), canvasWidth > 0, canvasHeight > 0, outputHeight > 0
else {
    fputs("usage: make-apng.swift <out.png> <delay-seconds> <canvas-width> <canvas-height> <output-height> <frame.png>...\n", stderr)
    exit(1)
}
let scale = Double(outputHeight) / canvasHeight
let outputWidth = Int((canvasWidth * scale).rounded())
let frames = arguments[6...].map { URL(fileURLWithPath: $0) }
let output = URL(fileURLWithPath: arguments[1])

guard let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, frames.count, nil) else {
    fputs("cannot create \(output.path)\n", stderr)
    exit(1)
}
CGImageDestinationSetProperties(destination, [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 0]] as CFDictionary)

for url in frames {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let context = CGContext(data: nil, width: outputWidth, height: outputHeight, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else {
        fputs("cannot read \(url.path)\n", stderr)
        exit(1)
    }
    context.interpolationQuality = .high
    let width = Double(image.width) * scale
    let height = Double(image.height) * scale
    context.draw(image, in: CGRect(x: (Double(outputWidth) - width) / 2, y: 0, width: width, height: height))
    guard let frame = context.makeImage() else { exit(1) }
    CGImageDestinationAddImage(destination, frame, [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: delay]] as CFDictionary)
}
exit(CGImageDestinationFinalize(destination) ? 0 : 1)
