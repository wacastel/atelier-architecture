import Foundation

struct ChicagoFact: Identifiable, Equatable {
    let id: Int
    let text: String
    let sourceID: String
    var source: ChicagoFactSource { ChicagoFacts.sources[sourceID]! }
}

struct ChicagoFactSource {
    let title: String
    let url: URL
}

/// Short, independently sourced facts for the loading screen. The complete
/// source ledger and wording are maintained in docs/CHICAGO-FACTS.md.
enum ChicagoFacts {
    static let sources: [String: ChicagoFactSource] = [
        "willis": .init(title:"Willis Tower",url:URL(string:"https://www.willistower.com/about")!),
        "pier": .init(title:"Navy Pier",url:URL(string:"https://navypier.org/support-the-pier/articles/navy-pier-through-the-years/")!),
        "wheel": .init(title:"Navy Pier",url:URL(string:"https://navypier.org/support-the-pier/articles/history-of-the-centennial-wheel-at-navy-pier/")!),
        "wheel-size": .init(title:"Chicago Architecture Center",url:URL(string:"https://www.architecture.org/online-resources/stories-of-chicago/chicagos-ferris-wheel-story")!),
        "field": .init(title:"Field Museum",url:URL(string:"https://www.fieldmuseum.org/page/history")!),
        "field-origin": .init(title:"Field Museum",url:URL(string:"https://www.fieldmuseum.org/museum-history")!),
        "shedd": .init(title:"Shedd Aquarium",url:URL(string:"https://www.sheddaquarium.org/about-shedd/vision/history")!),
        "adler": .init(title:"Adler Planetarium",url:URL(string:"https://www.adlerplanetarium.org/about-us/our-history/")!),
        "zeiss": .init(title:"Adler Planetarium",url:URL(string:"https://www.adlerplanetarium.org/blog/the-adler-planetariums-original-zeiss-projector/")!),
        "robie": .init(title:"Frank Lloyd Wright Trust",url:URL(string:"https://www.flwright.org/explore/frederick-c-robie-house")!),
        "wright-unesco": .init(title:"Frank Lloyd Wright Trust",url:URL(string:"https://www.flwright.org/about/unesco")!),
        "wrigley": .init(title:"National Park Service",url:URL(string:"https://www.nps.gov/orgs/1207/wrigley-field-designated-as-a-national-historic-landmark.htm")!),
        "wrigley-name": .init(title:"National Park Service",url:URL(string:"https://www.nps.gov/places/wrigley-field.htm")!),
        "lions": .init(title:"Chicago Park District",url:URL(string:"https://www.chicagoparkdistrict.com/parks-facilities/lions-artwork")!),
        "bean": .init(title:"Chicago Public Library",url:URL(string:"https://www.chipublib.org/fa-millennium-park-inc/")!),
        "cultural": .init(title:"City of Chicago",url:URL(string:"https://webapps1.chicago.gov/landmarksweb/web/landmarkdetails.htm?lanId=1274")!),
        "dome": .init(title:"Chicago Architecture Center",url:URL(string:"https://www.architecture.org/online-resources/buildings-of-chicago/chicago-cultural-center")!),
        "fountain": .init(title:"Chicago Park District",url:URL(string:"https://www.chicagoparkdistrict.com/parks-facilities/clarence-f-buckingham-memorial-fountain")!),
        "zoo": .init(title:"Lincoln Park Zoo",url:URL(string:"https://www.lpzoo.org/about-the-zoo/history/")!),
        "swans": .init(title:"Lincoln Park Zoo",url:URL(string:"https://www.lpzoo.org/exhibits/hope-b-mccormick-swan-pond/")!),
        "water-tower": .init(title:"Chicago Architecture Center",url:URL(string:"https://www.architecture.org/online-resources/buildings-of-chicago/chicago-water-tower")!),
        "planning": .init(title:"Chicago Public Library",url:URL(string:"https://www.chipublib.org/timeline-key-moments-in-chicago-planning/")!),
        "transit": .init(title:"Chicago Transit Authority",url:URL(string:"https://www.transitchicago.com/heritagefleet/")!),
        "transit-name": .init(title:"Chicago Transit Authority",url:URL(string:"https://www.transitchicago.com/about/")!),
        "flag": .init(title:"Chicago History Museum",url:URL(string:"https://www.chicagohistory.org/a-well-traveled-flag/")!)
    ]

    static let all: [ChicagoFact] = [
        .init(id:1,text:"Construction of Willis Tower began in 1970.",sourceID:"willis"),
        .init(id:2,text:"Willis Tower was the world's tallest building when completed in 1973.",sourceID:"willis"),
        .init(id:3,text:"Willis Tower rises 110 stories above Chicago.",sourceID:"willis"),
        .init(id:4,text:"Sears Tower received the name Willis Tower in 2009.",sourceID:"willis"),
        .init(id:5,text:"Willis Tower's broadcast antennas were added in 1982.",sourceID:"willis"),
        .init(id:6,text:"The tower's arched glass atrium on Wacker Drive arrived in 1985.",sourceID:"willis"),
        .init(id:7,text:"Catalog at Willis Tower spans five stories of shops and dining.",sourceID:"willis"),
        .init(id:8,text:"Willis Tower's antennas carry television and radio broadcasts across Chicago.",sourceID:"willis"),
        .init(id:9,text:"Navy Pier opened in 1916 under the name Municipal Pier.",sourceID:"pier"),
        .init(id:10,text:"Navy Pier was designed for both shipping and recreation.",sourceID:"pier"),
        .init(id:11,text:"Architect Charles Sumner Frost oversaw Navy Pier's construction.",sourceID:"pier"),
        .init(id:12,text:"Municipal Pier became Navy Pier in 1927.",sourceID:"pier"),
        .init(id:13,text:"Navy Pier's name honors naval personnel housed there during World War I.",sourceID:"pier"),
        .init(id:14,text:"Navy Pier reopened to the public in July 1995 after redevelopment.",sourceID:"pier"),
        .init(id:15,text:"The Centennial Wheel debuted for Navy Pier's hundredth anniversary in 2016.",sourceID:"wheel"),
        .init(id:16,text:"The Centennial Wheel has 42 gondolas and reaches 196 feet high.",sourceID:"wheel-size"),
        .init(id:17,text:"The Centennial Wheel's enclosed gondolas are climate controlled.",sourceID:"wheel"),
        .init(id:18,text:"Chicago's original 1893 Ferris wheel was built to rival the Eiffel Tower.",sourceID:"wheel"),
        .init(id:19,text:"The Field Museum first welcomed visitors in 1894.",sourceID:"field-origin"),
        .init(id:20,text:"The Field Museum grew from collections shown at Chicago's 1893 world's fair.",sourceID:"field-origin"),
        .init(id:21,text:"Marshall Field donated one million dollars to help establish his namesake museum.",sourceID:"field-origin"),
        .init(id:22,text:"The Field Museum's first home was the Palace of Fine Arts in Jackson Park.",sourceID:"field"),
        .init(id:23,text:"The Field Museum opened its current lakefront building in 1921.",sourceID:"field"),
        .init(id:24,text:"Peirce Anderson designed the Field Museum's present building.",sourceID:"field"),
        .init(id:25,text:"In 1920, museum specimens moved across Chicago by rail and horse-drawn carriage.",sourceID:"field"),
        .init(id:26,text:"The Field Museum's original displays included a giant redwood cross-section.",sourceID:"field"),
        .init(id:27,text:"Shedd Aquarium opened on May 30, 1930.",sourceID:"shedd"),
        .init(id:28,text:"John G. Shedd rose from stock boy to president of Marshall Field & Company.",sourceID:"shedd"),
        .init(id:29,text:"Shedd's original building has an eight-sided footprint.",sourceID:"shedd"),
        .init(id:30,text:"Real marine fossils are embedded in Shedd Aquarium's limestone floor.",sourceID:"shedd"),
        .init(id:31,text:"Neptune's trident crowns Shedd Aquarium's glass dome.",sourceID:"shedd"),
        .init(id:32,text:"Shedd's Oceanarium opened in 1991 with an exterior of white Georgia marble.",sourceID:"shedd"),
        .init(id:33,text:"Shedd's Wild Reef was built 25 feet below street level.",sourceID:"shedd"),
        .init(id:34,text:"The architects of Shedd Aquarium also worked on the Field Museum and Wrigley Building.",sourceID:"shedd"),
        .init(id:35,text:"Adler Planetarium opened on May 12, 1930.",sourceID:"adler"),
        .init(id:36,text:"The Adler was the first planetarium in the Western Hemisphere.",sourceID:"adler"),
        .init(id:37,text:"Max Adler funded the planetarium, its star projector and a collection of astronomical instruments.",sourceID:"adler"),
        .init(id:38,text:"Astronomer Philip Fox became the Adler's first director.",sourceID:"adler"),
        .init(id:39,text:"More than 1.2 million people visited the Adler during the 1933–34 world's fair.",sourceID:"adler"),
        .init(id:40,text:"The Adler's underground Astro-Science Center opened on its birthday in 1973.",sourceID:"adler"),
        .init(id:41,text:"Doane Observatory opened at the Adler in 1977.",sourceID:"adler"),
        .init(id:42,text:"The Adler's original 1930 star projector was a German-built Zeiss Mark II.",sourceID:"zeiss"),
        .init(id:43,text:"Frank Lloyd Wright's Robie House was completed in 1910.",sourceID:"robie"),
        .init(id:44,text:"Robie House is a defining example of Wright's Prairie style.",sourceID:"robie"),
        .init(id:45,text:"Robie House's long rooflines, brickwork and limestone emphasize the horizontal.",sourceID:"robie"),
        .init(id:46,text:"A central chimney separates Robie House's open living and dining spaces.",sourceID:"robie"),
        .init(id:47,text:"Robie House's art-glass patterns use diamonds and diagonal lines to evoke flowers.",sourceID:"robie"),
        .init(id:48,text:"Wright personally defended Robie House against demolition threats in 1941 and 1957.",sourceID:"robie"),
        .init(id:49,text:"The Wilbur family, who left in 1926, were Robie House's last family residents.",sourceID:"robie"),
        .init(id:50,text:"Robie House belongs to a UNESCO World Heritage group of eight Wright buildings.",sourceID:"wright-unesco"),
        .init(id:51,text:"Wrigley Field was built in 1914, two years before the Cubs moved in.",sourceID:"wrigley"),
        .init(id:52,text:"Wrigley Field originally opened as Weeghman Park.",sourceID:"wrigley-name"),
        .init(id:53,text:"The Chicago Bears played at Wrigley Field from 1921 to 1970.",sourceID:"wrigley"),
        .init(id:54,text:"Wrigley Field hosted the first NFL championship game in 1933.",sourceID:"wrigley"),
        .init(id:55,text:"Wrigley's famous ivy-covered outfield wall dates to the 1937 renovation.",sourceID:"wrigley"),
        .init(id:56,text:"Wrigley Field's 27-foot-high outfield scoreboard was added in 1937.",sourceID:"wrigley"),
        .init(id:57,text:"Wrigley Field added lights for night baseball in 1988.",sourceID:"wrigley"),
        .init(id:58,text:"Wrigley hosted the first tryouts for the All-American Girls Professional Baseball League.",sourceID:"wrigley"),
        .init(id:59,text:"Edward Kemeys sculpted the lions outside the Art Institute.",sourceID:"lions"),
        .init(id:60,text:"The Art Institute's bronze lions were installed in 1894.",sourceID:"lions"),
        .init(id:61,text:"Temporary plaster versions of the Art Institute's lions appeared at the 1893 world's fair.",sourceID:"lions"),
        .init(id:62,text:"The fair's lions guarded the Fine Arts Palace, now the Museum of Science and Industry.",sourceID:"lions"),
        .init(id:63,text:"A gift from Mrs. Henry Field funded the lions' transformation from plaster to bronze.",sourceID:"lions"),
        .init(id:64,text:"Anish Kapoor created Cloud Gate, the sculpture affectionately called the Bean.",sourceID:"bean"),
        .init(id:65,text:"Cloud Gate's seamless-looking skin is made from 168 stainless-steel plates.",sourceID:"bean"),
        .init(id:66,text:"Cloud Gate weighs 110 tons and stretches 66 feet long.",sourceID:"bean"),
        .init(id:67,text:"Cloud Gate's polished finish was intended to suggest liquid mercury.",sourceID:"bean"),
        .init(id:68,text:"Cloud Gate was formally dedicated on May 15, 2006.",sourceID:"bean"),
        .init(id:69,text:"The Chicago Cultural Center opened in 1897 as the city's first permanent public library building.",sourceID:"cultural"),
        .init(id:70,text:"Shepley, Rutan & Coolidge designed the Chicago Cultural Center.",sourceID:"cultural"),
        .init(id:71,text:"The Cultural Center's Tiffany dome spans 38 feet.",sourceID:"dome"),
        .init(id:72,text:"About 30,000 pieces of glass make up the Cultural Center's Tiffany dome.",sourceID:"dome"),
        .init(id:73,text:"Buckingham Fountain opened in 1927.",sourceID:"fountain"),
        .init(id:74,text:"Kate Buckingham gave the fountain to Chicago in memory of her brother Clarence.",sourceID:"fountain"),
        .init(id:75,text:"Architect Edward H. Bennett designed Buckingham Fountain.",sourceID:"fountain"),
        .init(id:76,text:"French sculptor Marcel Loyau created Buckingham Fountain's sculptural details.",sourceID:"fountain"),
        .init(id:77,text:"Buckingham Fountain combines pink Georgia marble, granite and bronze.",sourceID:"fountain"),
        .init(id:78,text:"Kate Buckingham wanted her fountain's lighting to resemble gentle moonlight.",sourceID:"fountain"),
        .init(id:79,text:"John Philip Sousa conducted his band at Buckingham Fountain's 1927 dedication.",sourceID:"fountain"),
        .init(id:80,text:"Buckingham Fountain's water operations were controlled manually until 1980.",sourceID:"fountain"),
        .init(id:81,text:"Lincoln Park Zoo traces its beginnings to 1868.",sourceID:"zoo"),
        .init(id:82,text:"Lincoln Park Zoo began with a gift of swans from New York's Central Park.",sourceID:"swans"),
        .init(id:83,text:"Lincoln Park Zoo offers free admission in the heart of the city.",sourceID:"zoo"),
        .init(id:84,text:"Chicago's historic Water Tower was completed in 1869.",sourceID:"water-tower"),
        .init(id:85,text:"William W. Boyington designed the Water Tower's castle-like Gothic Revival exterior.",sourceID:"water-tower"),
        .init(id:86,text:"The ornate Water Tower was built to conceal a practical water-system standpipe.",sourceID:"water-tower"),
        .init(id:87,text:"Engineers reversed the Chicago River's flow in 1900.",sourceID:"planning"),
        .init(id:88,text:"Chicago's elevated Loop connected passenger rail lines in 1897.",sourceID:"planning"),
        .init(id:89,text:"State and Madison streets anchor Chicago's street-numbering grid.",sourceID:"planning"),
        .init(id:90,text:"Chicago's standardized street-numbering system is named for Edward P. Brennan.",sourceID:"planning"),
        .init(id:91,text:"The 1909 Plan of Chicago was unveiled ceremonially on July 4.",sourceID:"planning"),
        .init(id:92,text:"The Chicago Sanitary and Ship Canal gave the reversed river a new route west.",sourceID:"planning"),
        .init(id:93,text:"Chicago's first elevated rapid-transit service began on June 6, 1892.",sourceID:"transit"),
        .init(id:94,text:"Early Chicago elevated trains used small steam locomotives.",sourceID:"transit"),
        .init(id:95,text:"The Chicago Transit Authority began operating in October 1947.",sourceID:"transit"),
        .init(id:96,text:"The nickname L is short for elevated, even though some trains run underground.",sourceID:"transit-name"),
        .init(id:97,text:"Wallace Rice designed the Chicago flag adopted in 1917.",sourceID:"flag"),
        .init(id:98,text:"Chicago's flag originally had just two red stars.",sourceID:"flag"),
        .init(id:99,text:"The flag's original stars represented the Great Fire and the 1893 world's fair.",sourceID:"flag"),
        .init(id:100,text:"Two stars added in the 1930s honored Fort Dearborn and the Century of Progress fair.",sourceID:"flag")
    ]
}

/// A shuffled bag shows every fact once before reshuffling and prevents a
/// repeat across bag boundaries. A delayed timer advances once, never in bursts.
struct ChicagoFactRotation {
    static let interval: Double = 3
    private(set) var currentIndex: Int?
    private var remaining: [Int] = []
    private var lastAdvance: Double?
    private let count: Int
    private var random: FactRandom

    init(count: Int = ChicagoFacts.all.count, seed: UInt64 = UInt64.random(in: .min ... .max)) {
        self.count=max(0,count)
        random=FactRandom(state:seed)
        chooseNext()
    }

    mutating func tick(at uptime: Double) -> Bool {
        guard uptime.isFinite else { return false }
        guard let previous=lastAdvance else { lastAdvance=uptime; return false }
        guard uptime-previous >= Self.interval else { return false }
        lastAdvance=uptime
        let before=currentIndex
        chooseNext()
        return currentIndex != before
    }

    private mutating func chooseNext() {
        guard count>0 else { return }
        if remaining.isEmpty {
            remaining=Array(0..<count)
            remaining.shuffle(using:&random)
            if count>1,remaining.last==currentIndex { remaining.swapAt(0,remaining.count-1) }
        }
        currentIndex=remaining.removeLast()
    }

    private struct FactRandom: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var value=state
            value=(value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
            value=(value ^ (value >> 27)) &* 0x94d049bb133111eb
            return value ^ (value >> 31)
        }
    }
}
