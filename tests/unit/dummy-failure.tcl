start_server {tags {"dummy external:skip"}} {
    test {Dummy failure 1} {
        assert_equal 1 2
    }

    test {Dummy failure 2} {
        fail "intentional failure for --failures-output verification"
    }
}
