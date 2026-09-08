import Foundation

/// One metre-scale world: both Chicago destinations see the same buildings,
/// sculpture reflections, illumination and collision geometry.
enum ChicagoWorld {
    static func build() -> SceneData {
        let builder = EiffelBuilder()
        builder.scene.name = "Chicago · Willis Tower, Millennium Park & Art Institute"
        builder.chicagoEnvironment()
        builder.willisTower()
        builder.millenniumPark()
        builder.artInstitute()
        return builder.scene
    }
}
