start_server {tags {"dummy"}} {
    test "dummy-a - passing test" {
        r SET key1 value1
        assert_equal [r GET key1] "value1"
    }

    test "dummy-a - failure one" {
        r SET key2 hello
        assert_equal [r GET key2] "world"
    }

    test "dummy-a - failure two" {
        r SET key3 100
        r INCR key3
        assert_equal [r GET key3] "999"
    }
}
