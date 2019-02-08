#!/usr/bin/env sage

import os, errno
import os.path
import sys
import fileinput
import datetime
from sage.all import *

# Unset env variables which seems to upset vivado
del os.environ['CPATH']
del os.environ['LIBRARY_PATH']

# Get current work directory
cwd = os.getcwd()

# Load files
load(cwd + '/script/entity.py')
load(cwd + '/script/domain_param.py')
load(cwd + '/script/testbench.py')
load(cwd + '/bls_sage_ref/bls.py')

# Check arguments
if len(sys.argv) != 3:
    print("Usage: %s <domain_param_id|all> <entity_id|all>" % sys.argv[0])
    print("Create test bench for specified ALU")

if len(sys.argv) < 2:
    print("Please specify domain parameters:")
    print("(all)")
    Domain_param.print_lst()
    sys.exit()

if len(sys.argv) < 3:
    print("Please specify entity id:")
    Entity.print_lst()
    sys.exit()

domain_param_arg = sys.argv[1]
if domain_param_arg == "all":
    domain_param_lst = Domain_param.lst()
else:
    domain_param_lst = [domain_param_arg]

entity_arg = sys.argv[2]
if entity_arg == "all":
    entity_lst = Entity.lst()
else:
    entity_lst = [entity_arg]

for domain_param_id in domain_param_lst:
    print "Start: ", domain_param_id
    dp = Domain_param.factory(domain_param_id)
    if dp:
        for entity_id in entity_lst:
            print "  Start: ", entity_id
            entity = Entity.factory(entity_id, dp)
            if entity:
                if entity.is_compatible_with(dp):
                    tb = entity.get_default_tb(dp)
                    tb.generate()
                    tb.do_simulation()
                else:
                    print dp.id + " is not compatible with " + entity_id + ", skipping"
                del entity
            print "  End: ", entity_id
        del dp
    print "End: ", domain_param_id

load(cwd + '/script/report.py')

# script end
