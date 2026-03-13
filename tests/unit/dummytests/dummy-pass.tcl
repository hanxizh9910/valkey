start_server {tags {"dummy"}} {
    test "dummy-pass - SET and GET" {
        r SET testkey testvalue
        assert_equal [r GET testkey] "testvalue"
    }

#    test "dummy-pass - INCR" {
#        r SET num 10
#        r INCR num
#        assert_equal [r GET num] "99"
#    }
}
