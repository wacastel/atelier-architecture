import Foundation

/// One metre-scale world: all Chicago destinations see the same buildings,
/// sculpture reflections, illumination and collision geometry.
enum ChicagoWorld {
    static func build() -> SceneData {
        let builder = EiffelBuilder()
        builder.scene.name = "Chicago · The Loop, Lakefront & Museum Campus"
        builder.chicagoEnvironment()
        builder.willisTower()
        builder.millenniumPark()
        builder.artInstitute()
        builder.magnificentMile()
        builder.magnificentGateway()
        builder.chicagoLakefront()
        builder.museumCampusEnvironment()
        builder.museumBuildings()
        builder.adlerPlanetarium()
        builder.soldierField()
        builder.mccormickPlace()
        return builder.scene
    }
}
