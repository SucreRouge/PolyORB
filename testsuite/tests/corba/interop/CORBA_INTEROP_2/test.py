
from test_utils import *
import sys

if not client_server(r'corba/interop/cpp/TAO/all_types_dynclient',
                     r'corba/interop/cpp/TAO/all_types_dynserver'):
    sys.exit(1)

