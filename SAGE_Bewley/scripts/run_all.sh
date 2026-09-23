#!/bin/bash
# Everything in one go, for the other machine: no time limit, worker counts from
# the memory probe, and the doubled asset grid row included. The same runner as
# the piecemeal sessions, so either machine can pick up the other's finished
# steps once they are pushed. See RUNBOOK_SECOND_MACHINE.md.
SESSION_HOURS=0 INCLUDE_NA400=1 PROBE=1 exec bash "$(dirname "$0")/run_session.sh" "$@"
