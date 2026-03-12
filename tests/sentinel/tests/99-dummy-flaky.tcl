test "sentinel-dummy - basic ping" {
    assert_equal {PONG} [S 0 PING]
}

#test "sentinel-dummy - intentional failure" {
#    assert_equal "wrong" [S 0 PING]
#}

test "sentinel-dummy - another passing test" {
    assert_equal {PONG} [S 1 PING]
}
