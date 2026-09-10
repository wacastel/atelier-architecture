import Foundation

var checks=0
func check(_ condition:@autoclosure ()->Bool,_ message:String) {
    checks+=1
    if !condition() { fputs("FAIL: \(message)\n",stderr);exit(1) }
}
let facts=ChicagoFacts.all
check(facts.count==100,"exactly 100 facts")
check(Set(facts.map(\.id)).count==100,"unique IDs")
check(facts.map(\.id)==Array(1...100),"stable contiguous IDs")
check(Set(facts.map(\.text)).count==100,"unique wording")
check(Set(facts.map(\.sourceID))==Set(ChicagoFacts.sources.keys),"all sources referenced")
for fact in facts {
    check(!fact.text.isEmpty && fact.text.count<=180,"readable card length \(fact.id)")
    check(ChicagoFacts.sources[fact.sourceID] != nil,"source exists \(fact.id)")
    check(fact.source.url.scheme=="https" && fact.source.url.host != nil,"source URL \(fact.id)")
    check(!fact.source.title.isEmpty,"source publisher \(fact.id)")
}

for seed in 0..<32 {
    var rotation=ChicagoFactRotation(seed:UInt64(seed))
    var replay=ChicagoFactRotation(seed:UInt64(seed))
    check(rotation.currentIndex != nil,"initial fact is immediate")
    check(!rotation.tick(at:0),"initial tick anchors time")
    check(!replay.tick(at:0),"replay anchors time")
    var order=[rotation.currentIndex!]
    for index in 1..<500 {
        let time=Double(index)*3
        check(!rotation.tick(at:time-0.001),"no change before three seconds")
        check(rotation.tick(at:time),"advance at three seconds")
        check(replay.tick(at:time),"deterministic replay advance")
        check(rotation.currentIndex==replay.currentIndex,"same seed sequence")
        check(rotation.currentIndex != order.last,"no adjacent repeat including bag boundary")
        order.append(rotation.currentIndex!)
    }
    for start in stride(from:0,to:500,by:100) {
        check(Set(order[start..<(start+100)])==Set(0..<100),"complete shuffled coverage")
    }
    check(Array(order.prefix(100)) != Array(0..<100),"bag is shuffled")
}
var timing=ChicagoFactRotation(seed:42)
let initial=timing.currentIndex
check(!timing.tick(at:.nan),"ignore NaN")
check(!timing.tick(at:.infinity),"ignore infinity")
check(!timing.tick(at:10),"anchor on valid time")
check(!timing.tick(at:9),"backward clock does not advance")
check(timing.currentIndex==initial,"invalid times preserve current fact")
check(timing.tick(at:1000),"delayed callback advances once")
let delayed=timing.currentIndex
check(!timing.tick(at:1000.1) && !timing.tick(at:1002.999),"no catch-up burst")
check(timing.currentIndex==delayed,"delayed card remains readable for full interval")
check(timing.tick(at:1003),"next full interval")
var empty=ChicagoFactRotation(count:0,seed:1)
check(empty.currentIndex==nil,"empty bag is safe")
check(!empty.tick(at:0) && !empty.tick(at:3),"empty bag never advances")
var single=ChicagoFactRotation(count:1,seed:1)
check(single.currentIndex==0,"single fact available")
check(!single.tick(at:0) && !single.tick(at:3),"single fact avoids spurious transitions")
let report:[String:Any]=["passed":true,"checks":checks,"facts":facts.count,"sources":ChicagoFacts.sources.count,
    "intervalSeconds":ChicagoFactRotation.interval,"seedsTested":32,"factsPerSeed":500,
    "scope":"Offline content integrity and shuffled three-second scheduling; not native UI or web availability."]
print(String(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
