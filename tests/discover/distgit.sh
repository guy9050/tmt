#!/bin/bash

. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun "tmp=\$(mktemp -d)" 0 "Create tmp directory"
        rlRun 'set -o pipefail'
        rlRun "git clone https://src.fedoraproject.org/rpms/tmt.git $tmp/tmt"
        rlRun "cp data/plans.fmf $tmp/tmt/plans"
        rlRun "export TMT_PLUGINS=$(pwd)/data"
        rlRun 'pushd $tmp'

        # server runs in $tmp
        rlRun "python3 -m http.server 9000 &> server.out &"
        SERVER_PID="$!"
        rlRun "rlWaitForSocket 9000 -t 5 -d 1"

        # prepare cwd for mock distgit tests
        rlRun "mkdir $tmp/mock_distgit"
        rlRun "pushd $tmp/mock_distgit"
        rlRun "git init" # should be git
        rlRun "tmt init" # should has fmf tree

        # Contains one test
        echo 'test: echo' > top_test.fmf

        (
            rlRun "mkdir -p $tmp/simple-1/tests"
            (
                rlRun "cd $tmp/simple-1"
                rlRun "tmt init"
            )
            echo 'test: echo' > "$tmp/simple-1/tests/magic.fmf"
            touch $tmp/outsider
            rlRun "tar czvf $tmp/simple-1.tgz --directory $tmp simple-1 outsider"
            rlRun "rm -rf $tmp/simple-1 outsider"
        )
        rlRun "popd"
    rlPhaseEnd

    rlPhaseStartTest "Detect within extracted sources (inner fmf root is used)"
        rlRun 'pushd $tmp/mock_distgit'

        echo -e "- url: simple-1.tgz\n  source_name: simple.tgz" > doit.yml

        WORKDIR=/var/tmp/tmt/XXX
        WORKDIR_SOURCE=$WORKDIR/plans/default/discover/default/source
        WORKDIR_TESTS=$WORKDIR/plans/default/discover/default/tests

        rlRun -s 'tmt run --id $WORKDIR --scratch plans --default \
             discover -vvv -ddd --how fmf --dist-git-source \
             --dist-git-type TESTING'
        rlAssertNotGrep "/top_test" $rlRun_LOG -F
        rlAssertGrep "/magic" $rlRun_LOG -F
        rlAssertGrep "summary: 1 test selected" $rlRun_LOG -F

        # Source dir has everything available
        rlAssertExists $WORKDIR_SOURCE/outsider
        rlAssertExists $WORKDIR_SOURCE/simple-1
        rlAssertExists $WORKDIR_SOURCE/simple.tgz

        # Test dir has only fmf_root from source
        rlAssertExists $WORKDIR_TESTS/tests/magic.fmf
        rlAssertNotExists $WORKDIR_TESTS/outsider
        rlAssertNotExists $WORKDIR_TESTS/simple-1
        rlAssertNotExists $WORKDIR_TESTS/simple.tgz

        rlRun 'popd'
    rlPhaseEnd

    rlPhaseStartTest "Detect within extracted sources and join with plan data (still respect fmf root)"
        rlRun 'pushd $tmp/mock_distgit'

        echo -e "- url: simple-1.tgz\n  source_name: simple.tgz" > doit.yml

        WORKDIR=/var/tmp/tmt/XXX
        WORKDIR_SOURCE=$WORKDIR/plans/default/discover/default/source
        WORKDIR_TESTS=$WORKDIR/plans/default/discover/default/tests

        rlRun -s 'tmt run --id $WORKDIR --scratch plans --default \
            discover -v --how fmf --dist-git-source \
            --dist-git-type TESTING --dist-git-merge'
        rlAssertGrep "/top_test" $rlRun_LOG -F
        rlAssertGrep "/magic" $rlRun_LOG -F
        rlAssertGrep "summary: 2 tests selected" $rlRun_LOG -F

        # Source dir has everything available
        rlAssertExists $WORKDIR_SOURCE/outsider
        rlAssertExists $WORKDIR_SOURCE/simple-1
        rlAssertExists $WORKDIR_SOURCE/simple.tgz

        # Only fmf_root from source was merged
        rlAssertExists $WORKDIR_TESTS/tests/magic.fmf
        rlAssertNotExists $WORKDIR_TESTS/outsider
        rlAssertNotExists $WORKDIR_TESTS/simple-1
        rlAssertNotExists $WORKDIR_TESTS/simple.tgz
        rlRun 'popd'
    rlPhaseEnd

    rlPhaseStartTest "Detect within extracted sources and join with plan data (override fmf root)"
        rlRun 'pushd $tmp/mock_distgit'

        echo -e "- url: simple-1.tgz\n  source_name: simple.tgz" > doit.yml

        WORKDIR=/var/tmp/tmt/XXX
        WORKDIR_SOURCE=$WORKDIR/plans/default/discover/default/source
        WORKDIR_TESTS=$WORKDIR/plans/default/discover/default/tests

        rlRun -s 'tmt run --id $WORKDIR --scratch plans --default \
            discover -v --how fmf --dist-git-source \
            --dist-git-type TESTING --dist-git-merge --dist-git-copy-path /simple*/tests'
        rlAssertGrep "/top_test" $rlRun_LOG -F
        rlAssertGrep "/magic" $rlRun_LOG -F
        rlAssertGrep "summary: 2 tests selected" $rlRun_LOG -F

        # Source dir has everything available
        rlAssertExists $WORKDIR_SOURCE/outsider
        rlAssertExists $WORKDIR_SOURCE/simple-1
        rlAssertExists $WORKDIR_SOURCE/simple.tgz

        # copy path set to /tests within sources, so simple-1 is not copied
        rlAssertExists $WORKDIR_TESTS/magic.fmf
        rlAssertNotExists $WORKDIR_TESTS/outsider
        rlAssertNotExists $WORKDIR_TESTS/simple-1
        rlAssertNotExists $WORKDIR_TESTS/simple.tgz
        rlRun 'popd'
    rlPhaseEnd

    rlPhaseStartTest "Detect within extracted sources and join with plan data (strip fmf root)"
        rlRun 'pushd $tmp/mock_distgit'

        echo -e "- url: simple-1.tgz\n  source_name: simple.tgz" > doit.yml

        WORKDIR=/var/tmp/tmt/XXX
        WORKDIR_SOURCE=$WORKDIR/plans/default/discover/default/source
        WORKDIR_TESTS=$WORKDIR/plans/default/discover/default/tests

        rlRun -s 'tmt run --id $WORKDIR --scratch plans --default \
            discover -v --how fmf --dist-git-source \
            --dist-git-type TESTING --dist-git-merge --dist-git-strip-fmf-root'
        rlAssertGrep "/top_test" $rlRun_LOG -F
        rlAssertGrep "/magic" $rlRun_LOG -F
        rlAssertGrep "summary: 2 tests selected" $rlRun_LOG -F

        # Source dir has everything available
        rlAssertExists $WORKDIR_SOURCE/outsider
        rlAssertExists $WORKDIR_SOURCE/simple-1
        rlAssertExists $WORKDIR_SOURCE/simple.tgz

        # fmf root stripped and dist-git-copy-path not set so everything is copied
        rlAssertExists $WORKDIR_TESTS/simple-1/tests/magic.fmf
        rlAssertExists $WORKDIR_TESTS/outsider
        rlAssertExists $WORKDIR_TESTS/simple-1
        rlAssertExists $WORKDIR_TESTS/simple.tgz
        rlRun 'popd'
    rlPhaseEnd

    rlPhaseStartTest "Run directly from the DistGit (Fedora) [cli]"
        rlRun 'pushd tmt'
        rlRun -s 'tmt run --remove plans --default \
            discover -v --how fmf --dist-git-source --dist-git-init \
            tests --name tests/prepare/install$'
        rlAssertGrep "summary: 1 test selected" $rlRun_LOG -F
        rlAssertGrep "/tests/prepare/install" $rlRun_LOG -F
        rlRun 'popd'
    rlPhaseEnd

    rlPhaseStartTest "Run directly from the DistGit (Fedora) [plan]"
        rlRun 'pushd tmt'
        rlRun -s 'tmt run --remove plans --name distgit discover -v'
        rlAssertGrep "summary: 1 test selected" $rlRun_LOG -F
        rlAssertGrep "/tests/prepare/install" $rlRun_LOG -F
        rlRun 'popd'
    rlPhaseEnd

    rlPhaseStartTest "URL is path to a local distgit repo"
        rlRun -s 'tmt run --remove plans --default \
            discover --how fmf --dist-git-source --dist-git-type fedora --url $tmp/tmt \
            --dist-git-init --dist-git-merge tests --name tests/prepare/install$'
        rlAssertGrep "summary: 1 test selected" $rlRun_LOG -F
    rlPhaseEnd

    for prefix in "" "/"; do
        rlPhaseStartTest "${prefix}path pointing to the fmf root in the extracted sources"
            rlRun 'pushd tmt'
            rlRun -s "tmt run --remove plans --default discover -v --how fmf \
            --dist-git-source --dist-git-merge --ref e2d36db --dist-git-copy-path ${prefix}tmt-*/tests/execute/framework/data \
            tests --name ^/tests/beakerlib/with-framework\$"
            rlAssertGrep "summary: 1 test selected" $rlRun_LOG -F
            rlRun 'popd'
        rlPhaseEnd
    done

    rlPhaseStartTest "Specify URL and REF of DistGit repo (Fedora)"
        rlRun -s 'tmt run --remove plans --default discover -v --how fmf \
        --dist-git-source --ref e2d36db --dist-git-merge  --dist-git-init \
        --url https://src.fedoraproject.org/rpms/tmt.git \
        tests --name tests/prepare/install$'
        rlAssertGrep "summary: 1 test selected" $rlRun_LOG -F
        rlAssertGrep "/tmt-1.7.0/tests/prepare/install" $rlRun_LOG -F
    rlPhaseEnd

    rlPhaseStartCleanup
        echo $SERVER_PID
        kill -9 $SERVER_PID
        rlRun 'popd'
    rlPhaseEnd
rlJournalEnd
