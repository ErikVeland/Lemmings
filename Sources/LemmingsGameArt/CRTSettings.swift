import Foundation
import simd

/// Display settings for the picture tube stage.
public struct CRTSettings: Sendable {
  public var curvature: Float
  public var curvatureY: Float
  public var cornerRadius: Float
  public var cornerSoftness: Float
  public var scanlineDepth: Float
  public var beamWidth: Float
  public var beamBloom: Float
  public var maskStrength: Float
  /// 0 is an aperture grille, 1 is a shadow mask.
  public var maskType: Float
  public var maskSize: Float
  public var maskDark: Float
  public var maskLight: Float
  public var bloomAmount: Float
  public var gamma: Float
  public var brightness: Float
  public var brightBoostDark: Float
  public var brightBoostBright: Float
  public var saturation: Float
  public var convergence: Float
  public var convergenceY: Float
  public var vignette: Float
  public var pixelAspect: Float
  /// 0 keeps full depth. 16 matches the Amiga OCS and ECS palette, which
  /// held four bits per channel.
  public var colorLevels: Float

  /// A Commodore 1084 style monitor, which is how most people saw an A500.
  ///
  /// A fine shadow mask, mild curvature, and aligned colour channels.
  public static let amiga1084 = CRTSettings(
    curvature: 24.0,
    curvatureY: 24.0,
    cornerRadius: 0.012,
    cornerSoftness: 0.006,
    scanlineDepth: 0.16,
    beamWidth: 0.30,
    beamBloom: 0.10,
    maskStrength: 0.10,
    maskType: 1,
    maskSize: 1.0,
    maskDark: 0.76,
    maskLight: 1.12,
    bloomAmount: 0.025,
    gamma: 2.2,
    brightness: 1.02,
    brightBoostDark: 1.08,
    brightBoostBright: 1.03,
    saturation: 1.02,
    convergence: 0,
    convergenceY: 0,
    vignette: 0.025,
    pixelAspect: 1.0,
    colorLevels: 16)

  /// A softer television with restrained glow and a fine aperture grille.
  public static let television = CRTSettings(
    curvature: 18.0,
    curvatureY: 24.0,
    cornerRadius: 0.022,
    cornerSoftness: 0.009,
    scanlineDepth: 0.22,
    beamWidth: 0.34,
    beamBloom: 0.16,
    maskStrength: 0.13,
    maskType: 0,
    maskSize: 1.0,
    maskDark: 0.70,
    maskLight: 1.18,
    bloomAmount: 0.045,
    gamma: 2.2,
    brightness: 1.03,
    brightBoostDark: 1.10,
    brightBoostBright: 1.05,
    saturation: 1.04,
    convergence: 0.10,
    convergenceY: 0.03,
    vignette: 0.04,
    pixelAspect: 1.15,
    colorLevels: 16)
}

public struct CRTUniforms: Sendable {
  public init() {}
  public var sourceSize: SIMD2<Float> = .zero
  public var outputSize: SIMD2<Float> = .zero
  public var curvature: Float = 0
  public var curvatureY: Float = 0
  public var cornerRadius: Float = 0
  public var cornerSoftness: Float = 0
  public var scanlineDepth: Float = 0
  public var beamWidth: Float = 0.4
  public var beamBloom: Float = 0
  public var maskStrength: Float = 0
  public var maskType: Float = 0
  public var maskSize: Float = 1
  public var maskDark: Float = 0.76
  public var maskLight: Float = 1.12
  public var bloomAmount: Float = 0
  public var gamma: Float = 2.4
  public var brightness: Float = 1
  public var brightBoostDark: Float = 1
  public var brightBoostBright: Float = 1
  public var saturation: Float = 1
  public var convergence: Float = 0
  public var convergenceY: Float = 0
  public var vignette: Float = 0
  public var pixelAspect: Float = 1
  public var colorLevels: Float = 0
  public var hdrHeadroom: Float = 1
}

