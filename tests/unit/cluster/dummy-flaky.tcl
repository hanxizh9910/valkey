start_cluster 3 3 {tags {"dummy"}} {
    test "cluster-dummy - nodes are reachable" {
        assert_equal {PONG} [R 0 PING]
        assert_equal {PONG} [R 1 PING]
    }

    test "cluster-dummy - intentional failure" {
        assert_equal "wrong" [R 0 PING]
    }
}
