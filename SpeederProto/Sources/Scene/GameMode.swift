import Foundation

/// How the world is played. The corridor scrolls the world past a fixed vehicle;
/// the arena moves a kinematic vehicle through a static world.
enum GameMode {
    case corridor
    case arena
}
