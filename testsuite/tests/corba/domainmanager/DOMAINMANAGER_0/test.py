
from test_utils import *
import sys

if not client_server(r'corba/domainmanager/test000/client', r'',
                     r'corba/domainmanager/test000/server', r''):
    sys.exit(1)

