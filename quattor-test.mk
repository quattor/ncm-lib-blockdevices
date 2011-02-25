###############################################################################
# quattor-test.mk
#
# Quattor unit testing makefile
#
# Marco Emilio Poleggi <marco.poleggi>@cern.ch
#
# $Id: quattor-test.mk,v 1.2 2006/06/19 15:28:03 poleggi Exp $
###############################################################################


###############################################################################
# General settings
###############################################################################

# test programs subdir local to component directory
_quattor_testdir=t

# test file list
QTTR_TESTLIST=test-list

# test harness program
_quattor_testharn=run-all-tests
