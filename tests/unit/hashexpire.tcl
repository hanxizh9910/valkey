start_server {tags {"hashexpire"}} {
    test {Expired hash fields are skipped during RDB load on primary} {
        r FLUSHALL
        
        # Step 1: Disable active expiration
        r DEBUG SET-ACTIVE-EXPIRE 0
        
        # Step 2: HSETEX many fields with small ttl (EX 1)
        r HSETEX myhash EX 1 FIELDS 3 f1 v1 f2 v2 f3 v3
        
        # Add a permanent field to verify selective skipping
        r HSET myhash permanent permanent_value
        
        # Wait for TTL to expire
        after 2000
        
        # Step 3: Save the RDB
        r SAVE
        
        # Step 4: Flushall
        r FLUSHALL
        
        # Step 5: Load the RDB
        r DEBUG RELOAD NOSAVE
        
        # Re-enable active expiration
        r DEBUG SET-ACTIVE-EXPIRE 1
        
        # Verify: expired fields were skipped, permanent field was loaded
        assert_equal 1 [r HLEN myhash]
        assert_equal "permanent_value" [r HGET myhash permanent]
        assert_equal "" [r HGET myhash f1]
        assert_equal "" [r HGET myhash f2]
        assert_equal "" [r HGET myhash f3]
    }
}