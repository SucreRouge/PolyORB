
from test_utils import *
import sys

if not client_server(r'corba/all_exceptions/client', r'scenarios/polyorb_conf/giop_1_2.conf',
                     r'corba/all_exceptions/server', r'scenarios/polyorb_conf/giop_1_2.conf'):
    sys.exit(1)
