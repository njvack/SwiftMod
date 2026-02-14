public enum VolumeEffect: Sendable, Equatable {
    case setVolume(Int)
    case volumeSlideUp(Int)
    case volumeSlideDown(Int)
    case fineVolumeSlideUp(Int)
    case fineVolumeSlideDown(Int)
    case vibratoSpeed(Int)
    case vibratoDepth(Int)
    case setPanning(Int)
    case panningSlideLeft(Int)
    case panningSlideRight(Int)
    case tonePortamento(Int)
}
