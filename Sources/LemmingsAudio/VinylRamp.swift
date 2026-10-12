import Foundation
import NxlvKit

/// Drives one vinyl stop or start against the clock on the main actor.
///
/// Each step applies the rate and gain from `VinylMotion`. A new run or a
/// cancel ends the previous run without its completion.
@MainActor public final class VinylRamp {
  public init() {}
  private var task: Task<Void, Never>?
  private var generation = 0

  public var isRunning: Bool { task != nil }

  public func run(_ phase: VinylMotion.Phase, apply: @escaping @MainActor (Double, Double) -> Void,
           completion: @escaping @MainActor () -> Void = {}) {
    cancel()
    generation += 1
    let current = generation
    let duration = VinylMotion.duration(phase)
    let started = ProcessInfo.processInfo.systemUptime
    let first = VinylMotion.sample(phase, progress: 0)
    apply(first.rate, first.gain)
    task = Task { @MainActor [weak self] in
      while true {
        do { try await Task.sleep(nanoseconds: 8_000_000) } catch { return }
        guard let self, self.generation == current else { return }
        let progress = (ProcessInfo.processInfo.systemUptime - started) / duration
        let sample = VinylMotion.sample(phase, progress: progress)
        apply(sample.rate, sample.gain)
        if progress >= 1 { break }
      }
      guard let self, self.generation == current else { return }
      self.task = nil
      completion()
    }
  }

  public func cancel() {
    generation += 1
    task?.cancel()
    task = nil
  }
}
