start_server {tags {"modules dummy"}} {
    test "moduleapi-dummy - basic SET and GET" {
        r SET mykey myvalue
        assert_equal [r GET mykey] "myvalue"
    }

#    test "moduleapi-dummy - intentional failure" {
#        r SET mykey myvalue
#        assert_equal [r GET mykey] "wrongvalue"
#    }

    test "moduleapi-dummy - another passing test" {
        r SET counter 0
        r INCR counter
        assert_equal [r GET counter] "1"
    }
}
