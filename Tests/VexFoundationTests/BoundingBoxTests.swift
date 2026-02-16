import Testing
@testable import VexFoundation

@Suite("BoundingBox")
struct BoundingBoxTests {

    @Test func initAndAccess() {
        let bb = BoundingBox(x: 10, y: 20, w: 100, h: 50)
        #expect(bb.x == 10)
        #expect(bb.y == 20)
        #expect(bb.w == 100)
        #expect(bb.h == 50)
    }

    @Test func move() {
        var bb = BoundingBox(x: 10, y: 20, w: 100, h: 50)
        bb.move(x: 5, y: -3)
        #expect(bb.x == 15)
        #expect(bb.y == 17)
    }

    @Test func merge() {
        var a = BoundingBox(x: 0, y: 0, w: 50, h: 50)
        let b = BoundingBox(x: 25, y: 25, w: 50, h: 50)
        a.mergeWith(b)
        #expect(a.x == 0)
        #expect(a.y == 0)
        #expect(a.w == 75)
        #expect(a.h == 75)
    }

    @Test func mergeContained() {
        var outer = BoundingBox(x: 0, y: 0, w: 100, h: 100)
        let inner = BoundingBox(x: 10, y: 10, w: 20, h: 20)
        outer.mergeWith(inner)
        // Should not change since inner is fully contained
        #expect(outer.x == 0)
        #expect(outer.y == 0)
        #expect(outer.w == 100)
        #expect(outer.h == 100)
    }
}
