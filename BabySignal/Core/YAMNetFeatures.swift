import Foundation

/// Google YAMNet's periodic Hann / magnitude STFT / log-mel front end at 16 kHz.
struct YAMNetFeatures {
  static let sampleCount = 15_600
  static let hopCount = 7_680
  private let window = (0..<400).map { Float(0.5 - 0.5 * cos(2 * .pi * Double($0) / 400)) }
  private let melWeights: [[Float]]

  init() {
    func mel(_ hz: Double) -> Double { 1127 * log(1 + hz / 700) }
    let low = mel(125), high = mel(7500)
    let edges = (0..<66).map { low + (high - low) * Double($0) / 65 }
    melWeights = (0..<64).map { band in
      (0..<257).map { bin in
        let value = mel(Double(bin) * 16_000 / 512)
        return Float(max(0, min((value - edges[band]) / (edges[band + 1] - edges[band]),
                               (edges[band + 2] - value) / (edges[band + 2] - edges[band + 1]))))
      }
    }
  }

  func extract(_ samples: [Float]) -> [Float] {
    precondition(samples.count >= Self.sampleCount)
    var output = [Float](repeating: 0, count: 96 * 64)
    for frame in 0..<96 {
      var real = [Float](repeating: 0, count: 512)
      var imaginary = [Float](repeating: 0, count: 512)
      for index in 0..<400 { real[index] = samples[frame * 160 + index] * window[index] }
      Self.fft(real: &real, imaginary: &imaginary)
      let magnitude = (0..<257).map { sqrt(real[$0] * real[$0] + imaginary[$0] * imaginary[$0]) }
      for band in 0..<64 {
        var energy: Float = 0
        for bin in 0..<257 { energy += magnitude[bin] * melWeights[band][bin] }
        output[frame * 64 + band] = log(energy + 0.001)
      }
    }
    return output
  }

  private static func fft(real: inout [Float], imaginary: inout [Float]) {
    let count = real.count
    var reverse = 0
    for index in 1..<count {
      var bit = count >> 1
      while reverse & bit != 0 { reverse ^= bit; bit >>= 1 }
      reverse ^= bit
      if index < reverse { real.swapAt(index, reverse); imaginary.swapAt(index, reverse) }
    }
    var length = 2
    while length <= count {
      let angle = -2 * Float.pi / Float(length)
      let stepReal = cos(angle), stepImaginary = sin(angle)
      for block in stride(from: 0, to: count, by: length) {
        var rotationReal: Float = 1, rotationImaginary: Float = 0
        for offset in 0..<(length / 2) {
          let first = block + offset, second = first + length / 2
          let valueReal = real[second] * rotationReal - imaginary[second] * rotationImaginary
          let valueImaginary = real[second] * rotationImaginary + imaginary[second] * rotationReal
          real[second] = real[first] - valueReal
          imaginary[second] = imaginary[first] - valueImaginary
          real[first] += valueReal
          imaginary[first] += valueImaginary
          let nextReal = rotationReal * stepReal - rotationImaginary * stepImaginary
          rotationImaginary = rotationReal * stepImaginary + rotationImaginary * stepReal
          rotationReal = nextReal
        }
      }
      length *= 2
    }
  }
}
