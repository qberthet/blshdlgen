class CURVE256(Domain_param):
    def __init__(self):
        self.id = "CURVE256"

        # Ground field prime modulus
        self.p = 57896044618658097711785492504343953926634992332820282019728792003956570372827

        # Ground finite field
        self.Fp = GF(self.p)

        # y^2 ≡ x^3 + B (mod p)
        self.E1 = EllipticCurve(self.Fp, [0,3])
        [self.A1,self.A2,self.A3,self.A4,self.A6] = self.E1.a_invariants()

        # E1 generator
        self.g = self.E1(1,2)

        # Generator order
        self.n = 4824670384888174809315457708695329493886249361068356834977399333663047531069

        # Cofactor
        self.c = self.E1.cardinality() / self.n

        # Embedding degree
        self.m = 2

        # Create polynomial ring with coefficient in Fp
        Pol.<btemp> = PolynomialRing(self.Fp)

        # Create prime extension field p^m , modulo a^2+1
        Fpm.<a> = GF(self.p^self.m, modulus=btemp^2+1)
        self.Fpm = Fpm

        # E2: Supersingular curve with equation y^2 ≡ x^3 + 3 (mod p) over GF(p^2)
        self.E2 = EllipticCurve(Fpm,[self.A4,self.A6])

        # Pre-compute twist constant
        xtemp1 = -self.Fp(1)/self.Fp(2)
        xtemp2 = sqrt(xtemp1^2+xtemp1+1)
        self.z = xtemp1 + xtemp2 * a

        #?is_supersingular()

obj = CURVE256()

