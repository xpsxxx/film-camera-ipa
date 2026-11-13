//
//  FilmAdjustments.swift
//  Film Camera
//

import Foundation

/// Image adjustments applied on top of the film LUT. All values are normalized
/// so the shader can consume them directly.
nonisolated struct FilmAdjustments: Codable, Equatable, Sendable {
    var lutIntensity: Float = 0.7
    var exposure: Float = 0.3    // EV, -2...2
    var contrast: Float = 0      // -1...1
    var highlights: Float = 0    // -1...1
    var shadows: Float = 0       // -1...1
    var saturation: Float = 0    // -1...1
    var temperature: Float = 0   // -1...1
    var tint: Float = 0          // -1...1
    var fade: Float = 0          // 0...1
    var grain: Float = 0.3       // 0...1
    var grainSize: Float = 0.35  // 0...1
    var glow: Float = 0.18       // 0...1
    var halation: Float = 0      // 0...1
    var vignette: Float = 0.1    // 0...1

    static let `default` = FilmAdjustments()
}

/// Describes one slider in the adjustments panel.
struct AdjustmentControl: Identifiable {
    enum Group: String, CaseIterable {
        case film = "胶片"
        case light = "光线"
        case color = "色彩"
        case effects = "特效"
    }

    let id: String
    let title: String
    let systemImage: String
    let group: Group
    let range: ClosedRange<Float>
    let keyPath: WritableKeyPath<FilmAdjustments, Float>

    var defaultValue: Float { FilmAdjustments.default[keyPath: keyPath] }
    var isBipolar: Bool { range.lowerBound < 0 }

    func formatted(_ value: Float) -> String {
        if keyPath == \FilmAdjustments.exposure {
            return String(format: "%+.1f EV", value)
        }
        let percent = Int((value * 100).rounded())
        return isBipolar && percent > 0 ? "+\(percent)" : "\(percent)"
    }

    static let all: [AdjustmentControl] = [
        .init(id: "intensity", title: "胶片强度", systemImage: "film", group: .film, range: 0...1, keyPath: \.lutIntensity),
        .init(id: "exposure", title: "曝光", systemImage: "plusminus.circle", group: .light, range: -2...2, keyPath: \.exposure),
        .init(id: "contrast", title: "对比度", systemImage: "circle.lefthalf.filled", group: .light, range: -1...1, keyPath: \.contrast),
        .init(id: "highlights", title: "高光", systemImage: "sun.max", group: .light, range: -1...1, keyPath: \.highlights),
        .init(id: "shadows", title: "阴影", systemImage: "moon", group: .light, range: -1...1, keyPath: \.shadows),
        .init(id: "fade", title: "褪色", systemImage: "circle.bottomhalf.filled", group: .light, range: 0...1, keyPath: \.fade),
        .init(id: "saturation", title: "饱和度", systemImage: "drop.halffull", group: .color, range: -1...1, keyPath: \.saturation),
        .init(id: "temperature", title: "色温", systemImage: "thermometer.medium", group: .color, range: -1...1, keyPath: \.temperature),
        .init(id: "tint", title: "色调", systemImage: "eyedropper.halffull", group: .color, range: -1...1, keyPath: \.tint),
        .init(id: "grain", title: "颗粒", systemImage: "circle.dotted", group: .effects, range: 0...1, keyPath: \.grain),
        .init(id: "grainSize", title: "颗粒粗细", systemImage: "circle.grid.3x3", group: .effects, range: 0...1, keyPath: \.grainSize),
        .init(id: "glow", title: "柔光", systemImage: "sparkles", group: .effects, range: 0...1, keyPath: \.glow),
        .init(id: "halation", title: "光晕", systemImage: "rays", group: .effects, range: 0...1, keyPath: \.halation),
        .init(id: "vignette", title: "暗角", systemImage: "circle.dashed", group: .effects, range: 0...1, keyPath: \.vignette),
    ]
}
