# BLS signature reference implementation

import binascii
import random
import sha3

class BLS():

    def __init__(self, dp):
        self.dp = dp

    def print_domain(self):
        print "Using:"
        print "  Field Fp =", self.dp.Fp
        print "  Curve E1 =", self.dp.E1
        print "  E1 generator g =", self.dp.g
        print "  generator order n =", self.dp.n
        print "  Curve cofactor c =", self.dp.c
        print "  Field F2 =", self.dp.F2
        print "  Curve E2 =", self.dp.E2

    def compress_point(self, P):
        (x, y) = P.xy()
        if Integer(y) > Integer(self.dp.p)/2:
            suf = 0b1
        else:
            suf = 0b0
        sig = (Integer(x) << 1) | suf
        return sig

    def decompress_point(self, sig):
        x = self.dp.Fp(sig >> 1)
        y0 = (x^3+3)^((self.dp.p+1)/4)
        y1 = -y0
        if sig & 0b1:
            if Integer(y0) > Integer(self.dp.p)/2:
                y = y0
            else:
                y = y1
        else:
            if Integer(y0) > Integer(self.dp.p)/2:
                y = y1
            else:
                y = y0
        P = self.dp.E1(x,y)
        return P

    # Create new point in G2 (E2), and twist the x coordinate of one of the point
    # by multiplying by twist contant
    # Notes:
    #  1) use global variables defined above for simplifying function signature
    #  2) use p+1 instead of #g
    def twisted_weil_pairing(self, P,Q):
        PE2 = self.dp.E2(P.xy())
        QE2 = self.dp.E2(Q.xy())
        PE2x,PE2y = PE2.xy()
        PE2twisted = self.dp.E2(PE2x*self.dp.z,PE2y)
        return PE2twisted.weil_pairing(QE2, self.dp.n)

    def map_to_point(self, m):
        h = sha3.keccak_512()
        h.update(m)
        hm = h.hexdigest()
        hint = ZZ("0x" + hm)
        y0 = self.dp.Fp(hint)
        exp = ((2*self.dp.p-1)/3)
        x0 = (y0**2 - 3)**exp
        return self.dp.E1(x0,y0)*Integer(self.dp.c)

    def key_gen(self, random = None):
        # Secret key: if no random provided, choose one
        if random == None:
            sk = ZZ.random_element(1,self.dp.p-1)
        else:
            sk = ZZ(self.dp.Fp(random))
        # Public key
        pk = self.compress_point(sk * self.dp.g)
        return (pk, sk)

    def sign(self, sk, m):
        # Hash to point on E1
        hm = self.map_to_point(m)
        # Compute signature with scalar multiplication of hash by secret key
        Psig = sk * hm
        sig = self.compress_point(Psig)
        return sig

    def verify(self, comp_pk, sig, m):
        # Hash to point on E1
        Psig = self.decompress_point(sig)
        pk = self.decompress_point(comp_pk)
        hm = self.map_to_point(m)
        pairing1 = self.twisted_weil_pairing(self.dp.g, Psig)
        pairing2 = self.twisted_weil_pairing(pk, hm)
        if pairing1 == pairing2:
            return True
        else:
            return False