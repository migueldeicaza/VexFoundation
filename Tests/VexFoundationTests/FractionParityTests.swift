import Testing
@testable import VexFoundation

@Suite("Fraction Parity")
struct FractionParityTests {

    @Test func basicParity() {
        let f1Over2 = Fraction(1, 2)
        #expect(f1Over2.value() == 0.5)
        #expect(f1Over2 == Fraction(1, 2))
        #expect(f1Over2 == Fraction(2, 4))

        #expect(!(f1Over2 > Fraction(1, 1)))
        #expect(f1Over2 > Fraction(1, 5))

        #expect(f1Over2 >= Fraction(1, 5))
        #expect(f1Over2 >= Fraction(1, 2))
        #expect(!(f1Over2 >= Fraction(1, 1)))

        #expect(!(f1Over2 < Fraction(1, 2)))
        #expect(f1Over2 < Fraction(1, 1))

        #expect(f1Over2 <= Fraction(3, 5))
        #expect(f1Over2 <= Fraction(1, 2))
        #expect(!(f1Over2 <= Fraction(2, 5)))

        let copied = Fraction().copy(Fraction(1, 2))
        #expect(copied.description == "1/2")
        #expect(copied.toSimplifiedString() == "1/2")

        let clone = copied.clone()
        #expect(clone !== copied)
        #expect(clone == copied)

        _ = clone.subtract(-1, 2)
        #expect(clone == Fraction(1, 1))
        _ = clone.add(1)
        #expect(clone == Fraction(2, 1))
        _ = clone.multiply(2)
        #expect(clone == Fraction(4, 1))
        _ = clone.divide(2)
        #expect(clone == Fraction(2, 1))

        #expect(Fraction.lcmm([]) == 0)
        #expect(Fraction.lcmm([17]) == 17)
        #expect(Fraction.lcmm([2, 5]) == 10)
        #expect(Fraction.lcmm([15, 3, 5]) == 15)
        #expect(Fraction.lcmm([2, 4, 6]) == 12)
        #expect(Fraction.lcmm([2, 3, 4, 5]) == 60)
        #expect(Fraction.lcmm([12, 15, 10, 75]) == 300)

        #expect(Fraction.gcd(0, 0) == 0)
        #expect(Fraction.gcd(0, 99) == 99)
        #expect(Fraction.gcd(77, 0) == 77)
        #expect(Fraction.gcd(42, 14) == 14)
        #expect(Fraction.gcd(15, 10) == 5)
    }

    @Test func withOtherFractionsParity() {
        let f1Over2 = Fraction(1, 2)
        let f1Over4 = Fraction(1, 4)
        let f1Over8 = Fraction(1, 8)
        let f2 = Fraction(2, 1)

        let a = f1Over2.clone().multiply(f1Over2)
        #expect(a == f1Over4)

        let b = f1Over2.clone().divide(f1Over4)
        #expect(b == f2)

        let c = f2.clone().subtract(f1Over2).subtract(f1Over2).subtract(f1Over4)
        let d = f1Over8.clone().add(f1Over8).add(f1Over8).multiply(f2)
        #expect(c == d)
        #expect(c.value() == 0.75)

        let e = f1Over8.clone().add(f1Over4).add(f1Over8)
        #expect(e == f1Over2)
    }
}
