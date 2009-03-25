#!/usr/bin/env gnatpython

"""test utils

This module is imported by all testcase. It parse the command lines options
and provide some usefull functions.

You should never call this module directly. To run a single testcase, use
 ./testsuite.py NAME_OF_TESTCASE
"""

from gnatpython.ex import Run, STDOUT
from gnatpython.fileutils import mkdir
from gnatpython.main import Main

import expect # this is in gnatpython only
import os
import re

def client_server(client_cmd, server_cmd):
    """Run a client server testcase

    Run server_cmd and extract the IOR string.
    Run client_cmd with the server IOR string
    Check for "END TESTS................   PASSED"
    if found return True
    """
    client = os.path.join(BASE_DIR, client_cmd)
    server = os.path.join(BASE_DIR, server_cmd)

    # Run the server command and retrieve the IOR string
    server_pid = expect.non_blocking_spawn(server, [])
    if not server_pid:
        print "Error when running " + server
        return False

    result = expect.expect (server_pid, [r"IOR:([a-z0-9]+)['|\n]"], 2.0)
    if result != 0:
        print "Expect error"
        expect.close(server_pid)
        return False

    IOR_str = expect.expect_out (server_pid, 2)

    # Run the client with the IOR argument
    mkdir(os.path.dirname(options.out_file))
    Run([client, IOR_str], output=options.out_file, error=STDOUT,
        timeout=options.timeout)

    # Kill the server process
    expect.close(server_pid)

    return _check_output()

def local(cmd):
    """Run a local test

    Execute the give command.
    Check for "END TESTS................   PASSED"
    if found return True
    """
    mkdir(os.path.dirname(options.out_file))
    command = os.path.join(BASE_DIR, cmd)
    Run([command], output=options.out_file, error=STDOUT,
        timeout=options.timeout)
    return _check_output()


def _check_output():
    """Check that END TESTS....... PASSED is contained in the output"""
    if os.path.exists(options.out_file):
        test_outfile = open(options.out_file)
        test_out = test_outfile.read()
        test_outfile.close()

        if re.search(r"END TESTS.*PASSED", test_out):
            return True
        else:
            print test_out
            return False

def parse_cmd_line():
    """Parse command line

    Returns options object
    """
    main = Main(require_docstring=False)
    main.add_option('--timeout', dest='timeout', type=int,
                    default=None)
    main.add_option('--build-dir', dest="build_dir")
    main.add_option('--out-file', dest="out_file")
    main.parse_args()
    return main.options

# Parse command lines options
options  = parse_cmd_line()

# All executable tests path are relative to PolyORB testsuite dir
BASE_DIR = os.path.join(options.build_dir, 'testsuite')
