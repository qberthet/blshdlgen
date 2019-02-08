def hex_to_K( s ):
    "test docstring"
    poly_bits = ZZ('0x'+s).bits()
    poly_str = ""
    for i in range(len(poly_bits)):
        if i == 0:
            if poly_bits[i] == 1:
                poly_str = " + 1"
        elif poly_bits[i] == 1:
            poly_str = " + x^"+ str(i) + poly_str
    if poly_str.startswith(" + "):
        poly_str = poly_str[3:]
    if poly_str == "":
        poly_str = "0"
    return poly_str

def point_coord_to_hex( pc ):
    "test docstring"
    test_list = pc.polynomial().list();
    test_hex = 0
    for i in range(len(test_list)):
        if test_list[i] == 1:
            test_hex += 2^i
    return test_hex