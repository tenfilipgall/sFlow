#!/usr/bin/env swift
// Extracts frames from a video file at a given interval using AVFoundation.
// Usage: swift sflow-video-extract.swift <video.mp4> <output_dir> [interval_sec=1.0]
import AVFoundation
import AppKit

guard CommandLine.arguments.count >= 3 else {
    fputs("usage: sflow-video-extract.swift <video> <outdir> [interval]\n", stderr)
    exit(1)
}

let videoPath = CommandLine.arguments[1]
let outDir    = CommandLine.arguments[2]
let interval  = Double(CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "1.0") ?? 1.0

let url    = URL(fileURLWithPath: videoPath)
let asset  = AVURLAsset(url: url)
let gen    = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.maximumSize = CGSize(width: 1600, height: 900)

let duration = asset.duration.seconds
guard duration > 0 else {
    fputs("sflow-video-extract: could not read duration from \(videoPath)\n", stderr)
    exit(2)
}

var times: [NSValue] = []
var t = 0.0
while t <= duration {
    times.append(NSValue(time: CMTime(seconds: t, preferredTimescale: 600)))
    t += interval
}

var index = 0
gen.generateCGImagesAsynchronously(forTimes: times) { _, image, _, result, error in
    defer { index += 1 }
    guard result == .succeeded, let cgImage = image else { return }
    let name = String(format: "f_%04d.png", index)
    let path = (outDir as NSString).appendingPathComponent(name)
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    if let data = bitmap.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

// Wait for async generation to finish.
Thread.sleep(forTimeInterval: Double(times.count) * 0.05 + 2.0)
print("sflow-video-extract: \(times.count) frames → \(outDir)")
