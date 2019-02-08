class TB_FIFO(TestBench):
    def __init__(self, dp, entity):
        TestBench.__init__(self, dp, entity)
        # FIXME factorize map_to_point, bls_sign and bls_verify entities common stuff here