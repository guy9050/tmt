#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "run=\$(mktemp -d)" 0 "Create run directory"
        rlRun "set -o pipefail"
        rlRun "pushd data"
        rlRun "git init"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "tmt --root tests run -i $run" 0
        rlAssertNotExists "$run/plans/example/discover/default/tests/foo"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "tmt --root tests run --scratch -ai $run discover -h fmf --sync-repo" 0
        rlAssertExists "$run/plans/example/discover/default/tests/foo"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -r $run" 0 "Remove run directory"
        rlRun "popd"
    rlPhaseEnd
rlJournalEnd
