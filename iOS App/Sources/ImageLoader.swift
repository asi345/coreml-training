import CoreML
import Vision

/**
  Loads the image files from the dataset into batches of MLFeatureValue objects.
 */
class ImageLoader {
  let dataset: ImageDataset
  let batchSize: Int
  let shuffle: Bool
  let augment: Bool
  let imageConstraint: MLImageConstraint

  private var batches: [[Int]] = []
  private(set) var index = 0

  typealias Batch = [(Int, MLFeatureValue)]

  /**
    Creates a new image loader.

    - Parameters:
      - dataset: which dataset to load the images from
      - batchSize: how many images at a time
      - shuffle: set this to true for training, false for testing
      - augment: set this to true for training, false for testing
      - imageConstraint: how large the image should be
   */
  init(dataset: ImageDataset,
       batchSize: Int = 1,
       shuffle: Bool = false,
       augment: Bool = false,
       imageConstraint: MLImageConstraint) {
    self.dataset = dataset
    self.batchSize = batchSize
    self.shuffle = shuffle
    self.augment = augment
    self.imageConstraint = imageConstraint
  }

  /** The number of batches. */
  var count: Int { batches.count }

  /**
    Returns the MLFeatureValue object for a single image.
   */
  func featureValue(at index: Int) throws -> MLFeatureValue {
    // How the image should be cropped and/or scaled. You can leave this nil
    // for default options.
    let imageOptions: [MLFeatureValue.ImageOption: Any] = [
      .cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue
    ]

    let imageURL = dataset.imageURL(at: index)

    // After this function returns, featureValue.imageBufferValue contains
    // the CVPixelBuffer object with the correct width / height for the model.
    return try MLFeatureValue(imageAt: imageURL, constraint: imageConstraint, options: imageOptions)
  }

  /** Begins a new epoch. */
  func reset() {
    batches = batches(size: batchSize, shuffle: shuffle)
    index = -1
  }

  /**
    Splits the dataset into batches of the given size. The last batch may be
    smaller. The returned batches contain indices.
   */
  private func batches(size: Int, shuffle: Bool) -> [[Int]] {
    let range = 0..<dataset.count
    let indices = shuffle ? range.shuffled() : Array(range)

    var batches: [[Int]] = []
    var thisBatch: [Int] = []
    var i = 0
    while i < dataset.count {
      thisBatch.append(indices[i])
      i += 1

      if thisBatch.count == size || i == dataset.count {
        batches.append(thisBatch)
        thisBatch = []
      }
    }
    return batches
  }

  /**
    Returns the next batch or nil if the epoch is finished.
   */
  private func nextBatchIndices() -> [Int]? {
    if index < count - 1 {
      index += 1
      return batches[index]
    } else {
      return nil
    }
  }

  /**
    Returns the next batch of images and their original index in the dataset,
    or nil if the epoch is finished.
   */
  func nextBatch() throws -> Batch? {
    guard let indices = nextBatchIndices() else { return nil }
    var features: Batch = []
    for index in indices {
      features.append((index, try featureValue(at: index)))
    }
    return features
  }
}
