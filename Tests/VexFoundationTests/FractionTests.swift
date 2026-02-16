import Testing
@testable import VexFoundation

@Suite("Fraction")
struct FractionTests {

    @Test func gcd() {
        #expect(Fraction.gcd(12, 8) == 4)
        #expect(Fraction.gcd(0, 5) == 5)
        #expect(Fraction.gcd(7, 0) == 7)
        #expect(Fraction.gcd(0, 0) == 0)
    }

    @Test func lcm() {
        #expect(Fraction.lcm(4, 6) == 12)
        #expect(Fraction.lcm(3, 5) == 15)
    }

    @Test func basicArithmetic() {
        let f = Fraction(1, 2)
        f.add(Fraction(1, 3))
        // 1/2 + 1/3 = 5/6
        #expect(f.numerator == 5)
        #expect(f.denominator == 6)

        let g = Fraction(3, 4)
        g.subtract(Fraction(1, 4))
        // 3/4 - 1/4 = 2/4
        #expect(g.numerator == 2)
        #expect(g.denominator == 4)
        g.simplify()
        #expect(g.numerator == 1)
        #expect(g.denominator == 2)
    }

    @Test func multiply() {
        let f = Fraction(2, 3)
        f.multiply(Fraction(3, 4))
        // 2/3 * 3/4 = 6/12
        f.simplify()
        #expect(f.numerator == 1)
        #expect(f.denominator == 2)
    }

    @Test func divide() {
        let f = Fraction(1, 2)
        f.divide(Fraction(1, 4))
        // (1/2) / (1/4) = 4/2
        f.simplify()
        #expect(f.numerator == 2)
        #expect(f.denominator == 1)
    }

    @Test func comparison() {
        let a = Fraction(1, 2)
        let b = Fraction(2, 4)
        #expect(a == b)

        let c = Fraction(3, 4)
        #expect(a < c)
        #expect(c > a)
    }

    @Test func value() {
        let f = Fraction(1, 4)
        #expect(f.value() == 0.25)
    }

    @Test func parse() {
        let f = Fraction()
        f.parse("5/2")
        #expect(f.numerator == 5)
        #expect(f.denominator == 2)
        #expect(f.quotient() == 2)
        #expect(f.remainder() == 1)
    }

    @Test func description() {
        let f = Fraction(6, 4)
        #expect(f.description == "6/4")
        #expect(f.toSimplifiedString() == "3/2")
    }
}
