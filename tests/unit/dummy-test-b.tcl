start_server {tags {"dummy"}} {
    test "dummy-b - passing test" {
        r SET foo bar
        assert_equal [r GET foo] "bar"
    }

    test "dummy-b - failure one" {
        r SET count 5
        assert_equal [r GET count] "10"
    }

    test "dummy-b - failure two" {
        r LPUSH mylist a b c
        assert_equal [r LLEN mylist] "99"
    }
}
